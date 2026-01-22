//
//  EntryCardWidgetView.swift
//  Mission Rock Events
//
//  Created by Joe Cieplinski on 5/8/25.
//

import SwiftUI

struct EntryCardWidgetView: View {
  let event: QuiEventEntity
  let image: UIImage?
  
  var body: some View {
    VStack(spacing: 6) {
      HStack {
        Text(event.title)
          .font(.title3)
          .fontWeight(.bold)
          .fontDesign(.rounded)
          .foregroundStyle(event.eventLocation.textColor)
          .multilineTextAlignment(.leading)
          .minimumScaleFactor(0.4)
          .lineLimit(2)
          .truncationMode(.tail)
        
        Spacer()
      }
      
      if let subtitle = event.subtitle {
        HStack {
          Text(event.title)
            .font(.body)
            .fontDesign(.rounded)
            .foregroundStyle(event.eventLocation.textColor.opacity(0.5))
            .multilineTextAlignment(.leading)
            .minimumScaleFactor(0.4)
            .lineLimit(2)
            .truncationMode(.tail)
          
          Spacer()
        }
      }
      
      Spacer(minLength: 1)
      
      if let image {
        Image(uiImage: image)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(maxWidth: 100, maxHeight: 100)
          .shadow(radius: 0.4)
      }
      
      Spacer(minLength: 1)
      
      HStack {
        Spacer()
        
        VStack {
          HStack {
            Spacer()
            
            Text(event.eventLocation.title)
              .font(.caption)
              .minimumScaleFactor(0.6)
              .fontWeight(.bold)
              .fontDesign(.rounded)
              .foregroundStyle(event.eventLocation.textColor)
          }
          
          HStack {
            Spacer()
            
            Text(event.date.formatted(date: .abbreviated, time: .shortened))
          }
          .font(.caption)
          .lineLimit(1)
          .minimumScaleFactor(0.4)
          .fontDesign(.rounded)
          .multilineTextAlignment(.trailing)
          .foregroundStyle(event.eventLocation.textColor)
        }
        .frame(maxWidth: .infinity)
      }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(
      event.eventLocation.backgroundColor
    )
  }
}

#Preview {
  VStack {
    EntryCardWidgetView(
      event: QuiEventEntity(event: QuiEvent.previewEvent),
      image: nil
    )
    .clipShape(RoundedRectangle(cornerRadius: 28))
  }
  .background(
    Image("backdrop")
      .blur(radius: 100)
      .saturation(0.3)
  )
  .padding()
}
