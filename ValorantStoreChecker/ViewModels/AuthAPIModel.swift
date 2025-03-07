//
//  LoginViewModel.swift
//  ValorantStoreChecker
//
//  Created by Gordon Ng on 2022-07-24.
//

import Foundation
import Keychain
import BackgroundTasks
import SwiftUI

class AuthAPIModel: ObservableObject {
    
    // Store
    @Published var storefront : [Skin] = []
    @Published var storePrice : [Offer] = []
    @Published var vp : String = ""
    @Published var rp : String = ""
    
    // Authentication
    @Published var isAuthenticated: Bool = false // Keeps user logged in
    @Published var isAuthenticating : Bool = false // Handles loading animation
    @Published var failedLogin : Bool = false // Handles login error message
    
    // Handles reload
    @Published var reloading : Bool = false
    @Published var successfulReload : Bool = false
    @Published var autoReload : Bool = false
    
    // Multifactor
    @Published var showMultifactor : Bool = false // Show multifactor popout
    @Published var enteredMultifactor : Bool = false // Handle multifactor loading animation
    @Published var email : String = "" // Displayed email for multifactor popout
    
    // User Information
    @Published var username: String = "" // Variable used by username box in LoginBoxView
    @Published var password: String = "" // Used by password box in LoginBoxView
    @Published var multifactor : String = "" // Used by multifactor box in MultifactorView
    @Published var regionCheck : Bool = false // COnfirm user has selected region
    @Published var rememberPassword : Bool = false
    
    // User saved information
    @Published var keychain = Keychain() // For sensitive information
    @Published var defaults = UserDefaults.standard // For general information
    
    // Error messages
    @Published var isError : Bool = false
    @Published var isReloadingError : Bool = false
    @Published var errorMessage : String = ""
    
    
    init() {
        
        // TODO: Implement CoreData, but for now lmao this works
        // Use saved storefront
        if let objects = defaults.value(forKey: "storefront") as? Data {
            let decoder = JSONDecoder()
            if let objectsDecoded = try? decoder.decode(Array.self, from: objects) as [Skin] {
                DispatchQueue.main.async{
                    self.storefront = objectsDecoded
                }
            }
        }
        
        // Use saved storeprice
        if let objects = defaults.value(forKey: "storePrice") as? Data {
            let decoder = JSONDecoder()
            if let objectsDecoded = try? decoder.decode(Array.self, from: objects) as [Offer] {
                DispatchQueue.main.async{
                    self.storePrice = objectsDecoded
                }
            }
        }
    }
    
    // MARK: Login
    @MainActor
    func login() async{
        
        do{
            
            if self.rememberPassword || defaults.bool(forKey: "rememberPassword"){
                self.username = keychain.value(forKey: "username") as? String ?? ""
                self.password = keychain.value(forKey: "password") as? String ?? ""
                print("Set username and password")
            }
            else if keychain.value(forKey: "username") == nil { // Save username to keychain
                let _ = keychain.save(self.username, forKey: "username")
            }
            
            try await WebService.getCookies()
            
            let tokenList = try await WebService.getToken(username: keychain.value(forKey: "username") as? String ?? "", password: self.password)
            
            if tokenList.count == 2 {
                // Multifactor login
                self.email = tokenList[1]
                self.showMultifactor = true
                self.isAuthenticating = false // Disable loading button in case user swipes away multifactor
            }
            else{
                // Default login (non-multifactor)
                let token = tokenList[0]
                await loginHelper(token: token)
                
                // Save authentication state for next launch
                self.isAuthenticated = true
                defaults.set(true, forKey: "authentication")
                
            }
            print("Finished login")
            
        }catch{
            // Reset user defaults
            self.email = ""
            self.showMultifactor = false
            
            if self.rememberPassword || defaults.bool(forKey: "rememberPassword"){
                
                self.isError = true
                self.isReloadingError = true
                
            }
            else {
                self.isAuthenticating = false
                self.failedLogin = true
                defaults.removeObject(forKey: "authentication")
                let _ = keychain.remove(forKey: "username")
                print("Login")
            }
            
            self.username = ""
            self.password = ""
            
            
        }
    }
    
    // MARK: LoginHelper
    @MainActor
    func loginHelper(token : String) async {
        do {
            self.password = "" // Clear password
            
            let riotEntitlement = try await WebService.getRiotEntitlement(token: token)
            let puuid = try await WebService.getPlayerInfo(token: token)
            let storefront = try await WebService.getStorefront(token: token, riotEntitlement: riotEntitlement, puuid: puuid, region: keychain.value(forKey: "region") as? String ?? "na")
            let wallet = try await WebService.getWallet(token: token, riotEntitlement: riotEntitlement, puuid: puuid, region: keychain.value(forKey: "region") as? String ?? "na")
            
            
            // Save user's wallet info
            
            self.vp = wallet[0]
            self.rp = wallet[1]
            
            self.defaults.set(wallet[0], forKey: "vp")
            self.defaults.set(wallet[1], forKey: "rp")
            
            // Match user's store with database
            var tempStore : [Skin] = []
            
            for skin in SkinModel().data{
                for level in skin.levels!{
                    for item in storefront.SingleItemOffers!{
                        if item == level.id.description.lowercased(){
                            tempStore.append(skin)
                        }
                    }
                }
            }
            
            self.storefront = tempStore
            
            let storefrontEncoder = JSONEncoder()
            
            if let encoded = try? storefrontEncoder.encode(tempStore){
                defaults.set(encoded, forKey: "storefront")
            }
            
            // Get store price
            let storePrice = try await WebService.getStorePrices(token: token, riotEntitlement: riotEntitlement, region: keychain.value(forKey: "region") as? String ?? "na")
            self.storePrice = storePrice
            
            // Save store prices
            let priceEncoder = JSONEncoder()
            if let encoded = try? priceEncoder.encode(storePrice){
                defaults.set(encoded, forKey: "storePrice")
            }
            
            // Set the time left in shop
            let referenceDate = Date() + Double(storefront.SingleItemOffersRemainingDurationInSeconds ?? 0)
            defaults.set(referenceDate, forKey: "timeLeft")
            defaults.set(Double(storefront.SingleItemOffersRemainingDurationInSeconds ?? 0), forKey: "secondsLeft")
            
            self.isAuthenticating = false

            self.username = ""
            self.password = ""
            self.multifactor = ""
            
        }catch {
            // Reset user defaults
            self.isAuthenticating = false
            self.failedLogin = true
            self.username = ""
            self.password = ""
            
            defaults.removeObject(forKey: "authentication")
            defaults.removeObject(forKey: "storefront")
            defaults.removeObject(forKey: "storePrice")
            
            let _ = keychain.remove(forKey: "ssid")
            let _ = keychain.remove(forKey: "tdid")
            let _ = keychain.remove(forKey: "region")
            let _ = keychain.remove(forKey: "username")
            print("LoginHelper")
            
            self.errorMessage = "Login Helper error: \(error.localizedDescription)"
            self.isError = true
        }
        
    }
    
    // MARK: Multifactor
    @MainActor
    func multifactor() async {
        if enteredMultifactor{
            do{
                let token = try await WebService.multifactor(code: self.multifactor)
                
                await loginHelper(token: token)
                self.showMultifactor = false
                self.enteredMultifactor = false
                
                self.isAuthenticated = true
                defaults.set(self.isAuthenticated, forKey: "authentication") // Save authentication state for next launch
            }
            catch{
                
                /*
                self.errorMessage = "Multifactor error, please enter the correct code."
                self.isError = true
                */
                
                // Reset user defaults
                self.enteredMultifactor = false
                self.multifactor = ""
                self.password = ""
                
                self.isAuthenticating = false
                self.failedLogin = true
                
                defaults.removeObject(forKey: "authentication")
                defaults.removeObject(forKey: "storefront")
                defaults.removeObject(forKey: "storePrice")
                
                let _ = keychain.remove(forKey: "ssid")
                let _ = keychain.remove(forKey: "tdid")
                print("Multifactor")
                
            }
            
        }
        
    }
    
    // MARK: Reload
    @MainActor
    func reload() async {
        do{
            
            let token = try await WebService.cookieReauth()
            let riotEntitlement = try await WebService.getRiotEntitlement(token: token)
            let puuid = try await WebService.getPlayerInfo(token: token)
            let storefront = try await WebService.getStorefront(token: token, riotEntitlement: riotEntitlement, puuid: puuid, region: keychain.value(forKey: "region") as? String ?? "na")
            let wallet = try await WebService.getWallet(token: token, riotEntitlement: riotEntitlement, puuid: puuid, region: keychain.value(forKey: "region") as? String ?? "na")
            
            self.defaults.set(wallet[0], forKey: "vp") // Store wallet for future launch
            self.defaults.set(wallet[1], forKey: "rp")
            
            let skinModel = SkinModel()
            
            var tempStore : [Skin] = []
            
            for skin in skinModel.data{
                for level in skin.levels!{
                    for item in storefront.SingleItemOffers!{
                        if item == level.id.description.lowercased(){
                            tempStore.append(skin)
                        }
                    }
                }
            }
            
            self.storefront = tempStore
            
            let storefrontEncoder = JSONEncoder()
            if let encoded = try? storefrontEncoder.encode(tempStore){
                defaults.set(encoded, forKey: "storefront")
            }
            
            let storePrice = try await WebService.getStorePrices(token: token, riotEntitlement: riotEntitlement, region: keychain.value(forKey: "region") as? String ?? "na")
            
            self.storePrice = storePrice
            
            let priceEncoder = JSONEncoder()
            if let encoded = try? priceEncoder.encode(storePrice){
                defaults.set(encoded, forKey: "storePrice")
            }
            
            let referenceDate = Date() + Double(storefront.SingleItemOffersRemainingDurationInSeconds ?? 0)
            
            defaults.set(referenceDate, forKey: "timeLeft")
            
            self.reloading = false
            
            
        }catch{
            
            if self.rememberPassword || defaults.bool(forKey: "rememberPassword") {
                
                await login()
                self.reloading = false
                
            }
            else {
                self.isError = true
                self.isReloadingError = true
            }
            
            
        }
    }
    
    // MARK: Log Out
    @MainActor
    func logOut() {
        
        // Create a new session
        WebService.session = {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 30 // seconds
            configuration.timeoutIntervalForResource = 30 // seconds
            return URLSession(configuration: configuration)
        }()
        
        
        
        // Reset Defaults
        self.isAuthenticating = false // Handles loading animation
        self.failedLogin = false // Handles login error message
        self.reloading = false
        self.showMultifactor = false // Show multifactor popout
        self.enteredMultifactor = false // Handle multifactor loading animation
        self.email = "" // Displayed email for multifactor popout
        self.username = "" // Variable used by username box in LoginBoxView
        self.password = "" // Used by password box in LoginBoxView
        self.multifactor = "" // Used by multifactor box in MultifactorView
        self.regionCheck = false
        self.successfulReload = false
        self.rememberPassword = false
        
        defaults.removeObject(forKey: "timeLeft")
        defaults.removeObject(forKey: "secondsLeft")
        defaults.removeObject(forKey: "vp")
        defaults.removeObject(forKey: "rp")
        defaults.removeObject(forKey: "storefront")
        defaults.removeObject(forKey: "storePrice")
        defaults.removeObject(forKey: "rememberPassword")
        defaults.removeObject(forKey: "autoReload")
        
        let _ = keychain.remove(forKey: "ssid")
        let _ = keychain.remove(forKey: "tdid")
        let _ = keychain.remove(forKey: "region")
        let _ = keychain.remove(forKey: "username")
        let _ = keychain.remove(forKey: "password")
        
        // Unauthenticate user
        self.isAuthenticated = false // Keeps user logged in
        defaults.removeObject(forKey: "authentication")

    }
    
    
}

func scheduleAppRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: "StoreRetriever")
    
    let defaults = UserDefaults.standard
    
    request.earliestBeginDate = .now.addingTimeInterval(defaults.double(forKey: "secondsLeft") + (4 * 3600)) // set time for 4 hours after store will refresh
    try? BGTaskScheduler.shared.submit(request)
}
