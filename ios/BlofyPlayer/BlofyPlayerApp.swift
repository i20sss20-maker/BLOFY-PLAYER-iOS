import SwiftUI
import AVKit

@main struct BlofyPlayerApp: App { var body: some Scene { WindowGroup { RootView() } } }

struct Playlist: Identifiable, Codable { var id=UUID(); var name:String; var url:String; var username:String=""; var password:String="" }

@MainActor final class Model: ObservableObject {
 @Published var playlists:[Playlist]=[]; @Published var selected:Playlist?; @Published var error=""
 init(){ if let d=UserDefaults.standard.data(forKey:"playlists"),let x=try? JSONDecoder().decode([Playlist].self,from:d){playlists=x;selected=x.first} }
 func save(){ if let d=try? JSONEncoder().encode(playlists){UserDefaults.standard.set(d,forKey:"playlists")} }
 func add(name:String,url:String,user:String,pass:String){ var u=url.trimmingCharacters(in:.whitespacesAndNewlines); if !u.contains("://"){u="http://"+u}; guard URL(string:u) != nil else {error="الرابط غير صالح";return}; let p=Playlist(name:name.isEmpty ? "BLOFY Playlist":name,url:u,username:user,password:pass); playlists.append(p);selected=p;save() }
}

struct RootView: View {
 @StateObject var model=Model(); @State private var showAdd=false
 var body: some View { NavigationStack { ZStack { Color(red:0.04,green:0.03,blue:0.07).ignoresSafeArea(); VStack(spacing:24){
  Text("BLOFY PLAYER").font(.system(size:34,weight:.black)).foregroundStyle(.white)
  Text("iOS Preview").foregroundStyle(.purple)
  if model.playlists.isEmpty {
   VStack(spacing:12){
    Image(systemName:"play.rectangle").font(.system(size:42,weight:.semibold)).foregroundColor(.purple)
    Text("لا توجد قائمة تشغيل").font(.headline)
    Text("أضف Xtream أو M3U للتجربة").font(.subheadline).foregroundColor(.secondary)
   }.padding(.vertical,28)
  }
  else { List(model.playlists){p in NavigationLink { PlaylistView(p:p) } label:{ VStack(alignment:.leading){Text(p.name).font(.headline);Text(p.url).font(.caption).lineLimit(1)} } }.scrollContentBackground(.hidden) }
  Button("إضافة قائمة تشغيل"){showAdd=true}.buttonStyle(.borderedProminent).tint(.purple)
 }}.foregroundStyle(.white) }.sheet(isPresented:$showAdd){AddView(model:model)} }
}

struct AddView: View {
 @Environment(\.dismiss) var dismiss; @ObservedObject var model:Model
 @State var name="";@State var url="";@State var user="";@State var pass=""
 var body: some View { NavigationStack { Form { TextField("اسم القائمة",text:$name);TextField("Server / M3U URL",text:$url).textInputAutocapitalization(.never);TextField("Username (Xtream)",text:$user).textInputAutocapitalization(.never);SecureField("Password",text:$pass);if !model.error.isEmpty{Text(model.error).foregroundStyle(.red)} } .navigationTitle("BLOFY") .toolbar { ToolbarItem(placement:.confirmationAction){Button("حفظ"){model.add(name:name,url:url,user:user,pass:pass);if model.error.isEmpty{dismiss()}}} } } }
}

struct MediaRow: Identifiable { let id=UUID();let name:String;let url:URL }

struct PlaylistView: View {
 let p:Playlist; @State var rows:[MediaRow]=[];@State var query="";@State var loading=false;@State var error=""
 var filtered:[MediaRow]{query.isEmpty ? rows:rows.filter{$0.name.localizedCaseInsensitiveContains(query)}}
 var body: some View { List { if loading{ProgressView("تحميل القوائم…")}; if !error.isEmpty{Text(error).foregroundStyle(.red)}; ForEach(filtered){r in NavigationLink(r.name){PlayerView(url:r.url,title:r.name)} } }.navigationTitle(p.name).searchable(text:$query,prompt:"بحث").task{await load()} }
 func load() async { guard rows.isEmpty else{return};loading=true;defer{loading=false};do{ if !p.username.isEmpty { try await loadXtream() } else { try await loadM3U() } }catch{self.error=error.localizedDescription} }
 func loadM3U() async throws { guard let u=URL(string:p.url) else{return};let(d,r)=try await URLSession.shared.data(from:u);guard (r as? HTTPURLResponse)?.statusCode ?? 500 < 400 else{throw URLError(.badServerResponse)};let text=String(data:d,encoding:.utf8) ?? "";var name="";var out:[MediaRow]=[];for raw in text.split(whereSeparator:\.isNewline){let l=String(raw).trimmingCharacters(in:.whitespaces);if l.hasPrefix("#EXTINF:"){name=l.split(separator:",",maxSplits:1).last.map(String.init) ?? "Channel"}else if !l.hasPrefix("#"),let u=URL(string:l){out.append(MediaRow(name:name.isEmpty ? u.lastPathComponent:name,url:u));name=""}};await MainActor.run{rows=out} }
 func loadXtream() async throws { guard var c=URLComponents(string:p.url.trimmingCharacters(in:CharacterSet(charactersIn:"/"))+"/player_api.php") else{return};c.queryItems=[.init(name:"username",value:p.username),.init(name:"password",value:p.password),.init(name:"action",value:"get_live_streams")];guard let u=c.url else{return};let(d,_)=try await URLSession.shared.data(from:u);guard let a=try JSONSerialization.jsonObject(with:d) as? [[String:Any]] else{return};let base=p.url.trimmingCharacters(in:CharacterSet(charactersIn:"/"));let out=a.compactMap{v->MediaRow? in guard let id=(v["stream_id"] as? NSNumber)?.stringValue ?? v["stream_id"] as? String,let u=URL(string:"\(base)/live/\(p.username)/\(p.password)/\(id).ts") else{return nil};return MediaRow(name:v["name"] as? String ?? id,url:u)};await MainActor.run{rows=out} }
}

struct PlayerView: View { let url:URL;let title:String;@State private var player:AVPlayer?;var body:some View{VideoPlayer(player:player).navigationTitle(title).navigationBarTitleDisplayMode(.inline).onAppear{let p=AVPlayer(url:url);player=p;p.play()}.onDisappear{player?.pause();player=nil}} }
