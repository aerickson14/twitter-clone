//
//  SettingsView.swift
//  TwitterCloneUI
//
//  Created by amos.gyamfi@getstream.io on 30.1.2023.
//  Copyright © 2023 Stream.io Inc. All rights reserved.
//

import SwiftUI
import TwitterCloneUI
import AuthUI
import Auth
import Feeds
import Chat
import DirectMessages
import RevenueCat

public struct SettingsView: View {
    @EnvironmentObject var feedsClient: FeedsClient
    @EnvironmentObject var auth: TwitterCloneAuth
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var purchaseViewModel: PurchaseViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @StateObject var mediaPickerViewModel = MediaPickerViewModel()
    
    @State private var isEditingName = "Amos Gyamfi"
    @State private var isEditingUserName = false
    @State private var isEditingPassword = false
    @State private var isLoggedOut = false
    public init () {}
    
    public var body: some View {
        NavigationStack {
            List {
                HStack {
                    Button {
                        print("Open the photo picker")
                    } label: {
                        HStack {
                            ZStack {
                                ProfileImage(imageUrl: "https://picsum.photos/id/64/200", action: {})
                                    .opacity(0.6)
                                MediaPickerView(viewModel: mediaPickerViewModel)
                            }
                            Image(systemName: "pencil")
                                .fontWeight(.bold)
                        }
                    }
                    
                    Spacer()
                }
                
                HStack {
                    Text("Change your Name")
                    TextField("Amos Gyamfi", text: $isEditingName)
                        .foregroundColor(.streamBlue)
                        .labelsHidden()
                }
                
                NavigationLink {
                    EditUserName()
                } label: {
                    Button {
                        self.isEditingUserName.toggle()
                    } label: {
                        HStack {
                            Text("Change your username")
                            Spacer()
                            Text("@stefanjblos")
                        }
                    }
                }
                
                NavigationLink {
                    EditPassword(auth: auth)
                } label: {
                    Button {
                        self.isEditingPassword.toggle()
                    } label: {
                        HStack {
                            Text("Change your password")
                            Spacer()
                        }
                    }
                }

                if purchaseViewModel.isSubscriptionActive {
                    Text("You are subscribed")
                        .padding(.top)
                } else {
                    if let packages = purchaseViewModel.offerings?.current?.availablePackages {
                        ForEach(packages) { package in
                            SubscribeBlue(package: package)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .frame(maxHeight: 280)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Your acount settings")
                }
            }
            
            Button(role: .destructive) {
                presentationMode.wrappedValue.dismiss()
                auth.logout()
//                chatModel.logout()
            } label: {
                Image(systemName: "power.circle.fill")
                Text("Log out")
            }
            
            Spacer()
        }
    }
}

//struct SettingsView_Previews: PreviewProvider {
//    static var previews: some View {
//        SettingsView()
//    }
//}
