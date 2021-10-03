//
//  BBNDailyWidget.swift
//  BBNDailyWidget
//
//  Created by Mike Veson on 10/2/21.
//

import WidgetKit
import SwiftUI
import Intents

struct Provider: IntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationIntent())
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), configuration: configuration)
        completion(entry)
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, configuration: configuration)
            entries.append(entry)
        }
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationIntent
}

struct BBNDailyWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            GeometryReader { geo in
                Color.init(UIColor(named: "background")!)
                Image("logo").resizable().aspectRatio(1, contentMode: .fit).frame(width: geo.size.height/3, height: geo.size.height/3, alignment: .topLeading)
                
                Text(entry.date, style: .time).frame(width: geo.size.width/1.04, height: geo.size.height/3, alignment: .trailing).foregroundColor(Color.init(UIColor(named: "inverse")!)).font(Font.system(size: 20, weight: .medium, design: .rounded))
                
                Divider().frame(width: geo.size.width, height: geo.size.height/1.5, alignment: .center)
            }
        }
    }
}

@main
struct BBNDailyWidget: Widget {
    let kind: String = "BBNDailyWidget"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { entry in
            BBNDailyWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Knight Life Widget")
    }
}

struct BBNDailyWidget_Previews: PreviewProvider {
    static var previews: some View {
        BBNDailyWidgetEntryView(entry: SimpleEntry(date: Date(), configuration: ConfigurationIntent()))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
