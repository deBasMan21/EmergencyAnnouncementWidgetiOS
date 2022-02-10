//
//  EmergencyWidget.swift
//  EmergencyWidget
//
//  Created by Bas Buijsen on 10/02/2022.
//

import WidgetKit
import SwiftUI
import Intents
import SWXMLHash

struct Provider: IntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), announcements: [])
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), announcements: [])
        completion(entry)
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task{
            var entries: [SimpleEntry] = []
            
            let items = try await apiCall()
            
            // Generate a timeline consisting of five entries an hour apart, starting from the current date.
            let currentDate = Date()
            for hourOffset in 0 ..< 5 {
                let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
                let entry = SimpleEntry(date: entryDate, announcements: items)
                entries.append(entry)
            }

            let timeline = Timeline(entries: entries, policy: .atEnd)
            completion(timeline)
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let announcements: [Announcement]
}

struct EmergencyWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("Meldingen in Brabant")
                    .bold()
                    .frame(height: 8)
                Spacer()
            }
            .padding()
            .background(Color.blue)
            
            Color.clear
                .overlay(
                    LazyVStack {
                        ForEach(entry.announcements){ item in
                            VStack(alignment: .leading){
                                HStack{
                                    Image(item.image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 44, height: 44, alignment: .center)
                                    
                                    VStack{
                                        Text(item.title)
                                        Text(item.description)
                                    }
                                }.padding(2)
                            }

                            Divider()
                        }
                    },
                    alignment: .top).padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@main
struct EmergencyWidget: Widget {
    let kind: String = "EmergencyWidget"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { entry in
            EmergencyWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("112Meldingen")
        .description("Alle 112 meldingen in de regio midden- en west-brabant")
        .supportedFamilies([.systemLarge, .systemMedium, .systemExtraLarge])
    }
}

func apiCall() async throws -> [Announcement] {
    let url = URL(string: "https://www.alarmeringen.nl/feeds/region/midden-en-west-brabant.rss")!
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    
    let(data, _) = try await URLSession.shared.data(for: request)

    let xml = XMLHash.parse(data)
    
    let items = xml["rss"]["channel"]["item"]
    
    var annList : [Announcement] = []
    
    for item in items.all {
        
        var ann = Announcement(title: item["title"].element?.text ?? "No title", description: item["description"].element?.text ?? "No description", link: item["link"].element?.text ?? "No link", pubDate: item["pubDate"].element?.text ?? "No date", speed: .unknown, type: .other, image: "help-circle")
        
        if ann.title.contains("a1") {
            ann.speed = .a1
        } else if ann.title.contains("a2"){
            ann.speed = .a2
        } else if ann.title.contains("b2") {
            ann.speed = .b2
        } else if ann.title.contains("p 1") {
            ann.speed = .p_1
        } else if ann.title.contains("p 2") {
            ann.speed = .p_2
        }
        
        if ann.description.contains("Ambulance") {
            ann.type = .ambulance
            ann.image = "ambulance"
        } else if ann.description.contains("Brand") || ann.speed == .p_2 || ann.speed == .p_1 {
            ann.type = .firefighters
            ann.image = "firefighter-helmet"
        }
        
        annList.append(ann)
    }
    
    return annList
}

struct Announcement: Identifiable {
    var id = UUID()
    var title: String
    var description: String
    var link: String
    var pubDate: String
    var speed : Speed
    var type : EmergencyType
    var image : String
}

enum Speed {
    case a1
    case a2
    case b2
    case p_1
    case p_2
    case unknown
}

enum EmergencyType {
    case ambulance
    case police
    case firefighters
    case other
}
