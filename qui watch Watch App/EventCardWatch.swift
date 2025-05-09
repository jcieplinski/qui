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
          .font(.title2)
          .fontWeight(.bold)
          .fontDesign(.rounded)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
        
        Spacer()
      }

      Spacer(minLength: 1)
      
      HStack {
        Image(event.eventType.image)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 60, height: 60)
        
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
