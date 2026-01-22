//
//  EventCard.swift
//  Mission Rock Events
//
//  Created by Joe Cieplinski on 5/7/25.
//

import SwiftUI

struct EventCard: View {
  @Environment(\.verticalSizeClass) private var verticalSizeClass

  let event: QuiEvent
  
  var body: some View {
    VStack {
      if verticalSizeClass == .regular {
        VStack {
          VStack(spacing: 6) {
            HStack {
              Text(event.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .foregroundStyle(event.eventLocation.textColor)
                .multilineTextAlignment(.leading)
              
              Spacer()
            }
            
            if let subtitle = event.subtitle {
              HStack {
                Text(subtitle)
                  .font(.body)
                  .fontWeight(.regular)
                  .fontDesign(.rounded)
                  .foregroundStyle(event.eventLocation.textColor.opacity(0.6))
                  .multilineTextAlignment(.leading)
                
                Spacer()
              }
            }
          }
          
          CachedAsyncImage(url: URL(string: event.imageURL ?? "")) { image in
            image
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(maxWidth: 220, maxHeight: 220)
              .shadow(radius: 0.4)
          } placeholder: {
            ProgressView()
          }
        }
      } else {
        HStack {
          VStack(spacing: 6) {
            HStack {
              Text(event.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .foregroundStyle(event.eventLocation.textColor)
                .multilineTextAlignment(.leading)
              
              Spacer()
            }
            
            if let subtitle = event.subtitle {
              HStack {
                Text(subtitle)
                  .font(.body)
                  .fontWeight(.regular)
                  .fontDesign(.rounded)
                  .foregroundStyle(event.eventLocation.textColor.opacity(0.6))
                  .multilineTextAlignment(.leading)
                
                Spacer()
              }
            }
          }
          
          Spacer()
          
          CachedAsyncImage(url: URL(string: event.imageURL ?? "")) { image in
            image
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(maxWidth: 220, maxHeight: 220)
              .shadow(radius: 0.4)
          } placeholder: {
            ProgressView()
          }
        }
      }
      
      Spacer()
      
      HStack {
        Spacer()
        
        VStack {
          HStack {
            Spacer()
            
            Text(event.eventLocation.title)
              .fontWeight(.bold)
              .fontDesign(.rounded)
              .foregroundStyle(event.eventLocation.textColor)
          }
          
          HStack {
            Spacer()
            
            Text(event.date.formatted(date: .abbreviated, time: .shortened))
          }
          .lineLimit(1)
          .minimumScaleFactor(0.4)
          .fontDesign(.rounded)
          .multilineTextAlignment(.trailing)
          .foregroundStyle(event.eventLocation.textColor)
        }
        .frame(maxWidth: .infinity)
      }
    }
    .padding(44)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(
      event.eventLocation.backgroundColor.opacity(0.6)
    )
  }
}

#Preview {
  VStack {
    EventCard(
      event: QuiEvent.previewEvent
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
