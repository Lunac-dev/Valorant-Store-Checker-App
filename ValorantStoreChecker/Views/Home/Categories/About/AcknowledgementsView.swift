//
//  AcknowledgementsView.swift
//  ValorantStoreChecker
//
//  Created by Gordon Ng on 2022-08-02.
//

import SwiftUI

struct AcknowledgementsView: View {
    var body: some View {
        HStack{
            
            VStack(alignment: .leading, spacing: 20) {
                
                Text(LocalizedStringKey("Acknowledgements"))
                    .bold()
                    .font(.title3)
                
                
                HStack{
                    Image("github")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25)
                        .padding(.trailing)
                    
                    Button {
                        if let url = URL(string: Constants.URL.julian) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        
                        VStack(alignment: .leading){
                            HStack{
                                Text("juliand665")
                                    .bold()
                                
                                Image(systemName: "link")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 15, height: 15)
                                    .padding(.trailing)
                            }
                            
                            
                            Text(LocalizedStringKey("ThankJulian"))
                                .multilineTextAlignment(.leading)
                                .font(.footnote)
                                
                        }
                        
                        Spacer()
                        
                        
                        
                    }
                    
                }
                
                HStack{
                    Image("github")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25)
                        .padding(.trailing)
                    
                    Button {
                        if let url = URL(string: Constants.URL.lunac) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        
                        VStack(alignment: .leading) {
                            HStack{
                                Text("Lunac")
                                    .bold()
                                
                                Image(systemName: "link")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 15, height: 15)
                                    .padding(.trailing)
                            }
                            
                            Text(LocalizedStringKey("ThankLunac"))
                                .font(.footnote)
                            
                        }
                        
                        
                        Spacer()
                    }
                    
                }
                
                
                
            }
            
            Spacer()
            
        }
        .padding()
        .foregroundColor(.white)
        .background(Blur(radius: 25, opaque: true))
        .cornerRadius(10)
        .overlay{
            RoundedRectangle(cornerRadius: 10)
                .stroke(.white, lineWidth: 3)
                .offset(y: -1)
                .offset(x: -1)
                .blendMode(.overlay)
                .blur(radius: 0)
                .mask {
                    RoundedRectangle(cornerRadius: 10)
                }
        }
    }
}

struct AcknowledgementsView_Previews: PreviewProvider {
    static var previews: some View {
        AcknowledgementsView()
    }
}
