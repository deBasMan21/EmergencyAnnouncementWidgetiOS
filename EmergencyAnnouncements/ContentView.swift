//
//  ContentView.swift
//  EmergencyAnnouncements
//
//  Created by Bas Buijsen on 10/02/2022.
//

import SwiftUI
import SWXMLHash

struct ContentView: View {
    @State var announcements : [Announcement] = []
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack{
                HStack {
                    Spacer()
                    Text("Meldingen in Brabant")
                        .bold()
                        .frame(height: 8)
                    Spacer()
                }
                HStack{
                    Spacer()
                    
                    Image("refresh")
                        .onTapGesture{
                            Task{
                                announcements = []
                                announcements = try await apiCall()
                            }
                        }
                }
            }
            .padding()
                .background(Color.blue)
            
            ScrollView{
                LazyVStack {
                    ForEach(announcements){ item in
                        Link(destination: URL(string: item.link)!, label: {
                            VStack(alignment: .leading){
                                HStack{
                                    Image(item.image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 44, height: 44, alignment: .center)
                                    
                                    VStack{
                                        Text(item.title).foregroundColor(getColorForEmergency(emer: item.type))
                                        Text(item.description).foregroundColor(.accentColor)
                                    }
                                }.padding(2)
                            }

                            Divider()
                        })
                        
                    }
                }
            }
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear{
            Task{
                announcements = try await apiCall()
            }
        }
    }
    
    func getColorForEmergency(emer: EmergencyType) -> Color {
        if emer == .firefighters {
            return .red
        } else if emer == .ambulance {
            return .yellow
        } else if emer == .police {
            return .blue
        } else if emer == .trauma {
            return .green
        } else {
            return .cyan
        }
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
        
        if ann.description.contains("Ambulance") || ann.speed == .a1 || ann.speed == .a2 || ann.speed == .b2{
            ann.type = .ambulance
            ann.image = "ambulance"
        } else if ann.description.contains("Brand") || ann.speed == .p_2 || ann.speed == .p_1 {
            ann.type = .firefighters
            ann.image = "firefighter-helmet"
        } else if ann.description.contains("Trauma") || ann.description.contains("heli") {
            ann.type = .trauma
            ann.image = "heli"
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
    case trauma
}
