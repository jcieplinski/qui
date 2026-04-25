//
//  EntryCardWidgetView.swift
//  Mission Rock Events
//
//  Created by Joe Cieplinski on 5/8/25.
//

import SwiftUI
import WidgetKit

struct EntryCardWidgetView: View {
  let event: QuiEventEntity
  let image: UIImage?
  let eventIndex: Int
  let eventCount: Int

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
          Text(subtitle)
            .font(.body)
            .fontDesign(.rounded)
            .foregroundStyle(event.eventLocation.textColor.opacity(0.6))
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
        if eventCount > 1 {
          EventNavigationButtons(
            eventIndex: eventIndex,
            eventCount: eventCount,
            textColor: event.eventLocation.textColor
          )
        }

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
      }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(
      event.eventLocation.backgroundColor
    )
  }
}

struct EventNavigationButtons: View {
  let eventIndex: Int
  let eventCount: Int
  let textColor: Color

  var body: some View {
    HStack(spacing: 4) {
      Button(intent: PreviousEventIntent()) {
        Image(systemName: "chevron.left")
          .font(.caption2)
          .fontWeight(.bold)
      }
      .buttonStyle(.plain)
      .disabled(eventIndex == 0)
      .opacity(eventIndex == 0 ? 0.3 : 1.0)

      Text("\(eventIndex + 1)/\(eventCount)")
        .font(.caption2)
        .fontWeight(.semibold)
        .fontDesign(.rounded)

      Button(intent: NextEventIntent()) {
        Image(systemName: "chevron.right")
          .font(.caption2)
          .fontWeight(.bold)
      }
      .buttonStyle(.plain)
      .disabled(eventIndex >= eventCount - 1)
      .opacity(eventIndex >= eventCount - 1 ? 0.3 : 1.0)
    }
    .foregroundStyle(textColor)
  }
}

#Preview {
  VStack {
    EntryCardWidgetView(
      event: QuiEventEntity(event: QuiEvent.previewEvent),
      image: nil,
      eventIndex: 0,
      eventCount: 3
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
