//
//  MediaPickerView.swift
//  Profile
//
//  Created by amos.gyamfi@getstream.io on 31.1.2023.
//  Copyright © 2023 Stream.io Inc. All rights reserved.
//

import SwiftUI
import PhotosUI

public struct MediaPickerView: View {
    @State var selectedPhotoItem: [PhotosPickerItem] = []
    // Store information about the selected photo that might be there or missing
    @State var data: Data?
    
    public init() {}
    
    public var body: some View {
        VStack {
            if let data = data, let uiimage = UIImage(data: data) {
                Image(uiImage: uiimage)
                    .resizable()
            }
            
            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images
            ) {
                Button {
                    print("tap to upload an image")
                } label: {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
            }
        }
    }
}

struct MediaPickerView_Previews: PreviewProvider {
    static var previews: some View {
        MediaPickerView()
    }
}
