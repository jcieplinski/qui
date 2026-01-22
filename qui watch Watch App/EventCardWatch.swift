//
//  EventCardWatch.swift
//  qui
//
//  Created by Joe Cieplinski on 5/9/25.
//

import SwiftUI

struct EventCardWatch: View {
  let event: QuiEvent
  
  var body: some View {
    VStack(spacing: 4) {
      HStack {
        Text(event.title)
          .font(.title)
          .fontWeight(.bold)
          .fontDesign(.rounded)
          .multilineTextAlignment(.leading)
          .allowsTightening(true)
          .minimumScaleFactor(0.3)
          .lineLimit(3)
          .lineSpacing(0.5)
        
        Spacer()
      }
      
      if let subtitle = event.subtitle {
        HStack {
          Text(subtitle)
            .font(.body)
            .fontDesign(.rounded)
            .multilineTextAlignment(.leading)
            .allowsTightening(true)
            .minimumScaleFactor(0.3)
            .lineLimit(3)
            .lineSpacing(0.5)
          
          Spacer()
        }
      }

      Spacer(minLength: 1)
      
      HStack {
        CachedAsyncImage(url: URL(string: event.imageURL ?? "")) { image in
          image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: 60, maxHeight: 60)
        } placeholder: {
          ProgressView()
        }

        Spacer(minLength: 6)
        
        VStack {
          HStack {
            Spacer()
            
            Text(event.eventLocation.title)
              .fontWeight(.bold)
              .fontDesign(.rounded)
          }
          
          HStack {
            Spacer()
            
            Text(event.date.formatted(date: .abbreviated, time: .shortened))
          }
          .lineLimit(2)
          .minimumScaleFactor(0.4)
          .fontDesign(.rounded)
          .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity)
      }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

#Preview {
  EventCardWatch(
    event: QuiEvent.previewEvent
  )
}
