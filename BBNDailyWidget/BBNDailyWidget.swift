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
    func placeholder(in context: Context) -> ClassEntry {
//        ClassEntry(date: Date(), configuration: ConfigurationIntent())
        ClassEntry(date: Date(), title: "No School Yet", startTime: "", endTime: "", configuration: ConfigurationIntent())
    }
    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (ClassEntry) -> ()) {
        let entry: ClassEntry
        let date = Date()
        if context.isPreview {
            entry = ClassEntry(date: date, title: "-", startTime: "", endTime: "", configuration: configuration)
        }
        else {
            entry = ClassEntry(date: date, title: "Precalculus BC 282", startTime: "09:00am", endTime: "09:50am", configuration: configuration)
        }
        
        completion(entry)
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [ClassEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
//            let entry = ClassEntry(date: entryDate, configuration: configuration)
            let entry = ClassEntry(date: entryDate, title: "", startTime: "", endTime: "", configuration: configuration)
            entries.append(entry)
        }
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct ClassEntry: TimelineEntry {
    let date: Date
    let title: String
    let startTime: String
    let endTime: String
    let configuration: ConfigurationIntent
}

struct BBNDailyWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            GeometryReader { geo in
                Color.init(UIColor(named: "blue")!)
                Image("logo").resizable().aspectRatio(1, contentMode: .fit).frame(width: geo.size.height/3, height: geo.size.height/3, alignment: .topLeading)
                
                Text(entry.date, style: .time).frame(width: geo.size.width/1.04, height: geo.size.height/3, alignment: .trailing).foregroundColor(Color.init(UIColor(named: "white")!)).font(Font.system(size: 20, weight: .medium, design: .rounded))
                
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
        BBNDailyWidgetEntryView(entry: ClassEntry(date: Date(), title: "", startTime: "", endTime: "", configuration: ConfigurationIntent()))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
