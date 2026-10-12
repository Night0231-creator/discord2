import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() => runApp(const VeylorApp());
const accent = Color(0xFF7565EE);
const surface = Color(0xFF202127);
const sidebar = Color(0xFF15161B);

class Api {
  Api(this.baseUrl);
  final String baseUrl;
  String? token;
  Future<Map<String,dynamic>> request(String method, String route, [Map<String,dynamic>? body]) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.openUrl(method, Uri.parse(baseUrl + route));
      req.headers.contentType = ContentType.json;
      if(token != null) req.headers.set('Authorization','Bearer ' + token!);
      if(body != null) req.write(jsonEncode(body));
      final response = await req.close().timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(await utf8.decoder.bind(response).join()) as Map<String,dynamic>;
      if(response.statusCode >= 400) throw Exception(decoded['error'] ?? 'Erro HTTP');
      return decoded;
    } finally {
      client.close(force:true);
    }
  }
}
class VeylorApp extends StatelessWidget {
  const VeylorApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title:'Veylor 2.0',debugShowCheckedModeBanner:false,
    theme:ThemeData.dark(useMaterial3:true).copyWith(
      scaffoldBackgroundColor:const Color(0xFF292B34),
      colorScheme:const ColorScheme.dark(primary:accent,surface:surface),
      inputDecorationTheme:InputDecorationTheme(
        filled:true,fillColor:sidebar,
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide.none))),
    home:const Home());
}
class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState()=>_HomeState();
}
class _HomeState extends State<Home> {
  final api=Api(const String.fromEnvironment('VEYLOR_API_URL',defaultValue:'http://127.0.0.1:8080'));
  final user=TextEditingController(),password=TextEditingController(),message=TextEditingController();
  Timer? polling,retrySocket;
  WebSocket? socket;
  final storage=const FlutterSecureStorage();
  bool restoring=true,realtime=false;
  String? nick,serverId,channelId,dmId,error;
  List<Map<String,dynamic>> dms=[];
  bool signup=false,busy=false;
  List<Map<String,dynamic>> servers=[],channels=[],messages=[];
  int cursor=0;
  @override
  void initState(){super.initState();restoreSession();}
  @override
  void dispose() {
    polling?.cancel();retrySocket?.cancel();socket?.close();
    user.dispose();password.dispose();message.dispose();super.dispose();
  }
  Future<void> restoreSession() async {
    try {
      final saved=await storage.read(key:'veylor_session');
      if(saved!=null&&saved.isNotEmpty){
        api.token=saved;
        final profile=await api.request('GET','/api/me');
        nick=(profile['user'] as Map<String,dynamic>)['username'] as String;
        await loadServers();await loadDms();startRealtime();
      }
    }catch(_){
      api.token=null;
      try{await storage.delete(key:'veylor_session');}catch(_){}
    }finally{if(mounted)setState(()=>restoring=false);}
  }
  void startRealtime(){
    polling?.cancel();
    polling=Timer.periodic(const Duration(seconds:30),(_){refresh();loadDms();});
    connectSocket();
  }
  Future<void> connectSocket() async {
    final token=api.token;
    if(token==null||socket!=null)return;
    try {
      final url=Uri.parse(api.baseUrl);
      final wsUrl=url.replace(scheme:url.scheme=='https'?'wss':'ws',path:'/api/realtime',query:null);
      final ws=await WebSocket.connect(wsUrl.toString(),
        headers:{HttpHeaders.authorizationHeader:'Bearer '+token});
      if(!mounted||api.token!=token){ws.close();return;}
      socket=ws;
      setState(()=>realtime=true);
      ws.listen((data){
        try {
          final event=jsonDecode(data as String) as Map<String,dynamic>;
          final type=event['type'];
          if(type=='channel.message'&&event['channel_id']==channelId&&dmId==null)refresh();
          if(type=='dm.message'&&event['thread_id']==dmId)refresh();
          if(type=='dm.updated'||type=='dm.message')loadDms();
          if(type=='server.updated'||type=='server.removed')loadServers();
        }catch(_){}
      },onError:(_){},onDone:(){
        if(identical(socket,ws))socket=null;
        if(mounted)setState(()=>realtime=false);
        if(api.token!=null&&mounted){
          retrySocket?.cancel();
          retrySocket=Timer(const Duration(seconds:4),connectSocket);
        }
      },cancelOnError:false);
    }catch(_){
      if(mounted)setState(()=>realtime=false);
      if(api.token!=null&&mounted){
        retrySocket?.cancel();
        retrySocket=Timer(const Duration(seconds:6),connectSocket);
      }
    }
  }
  Future<void> loadDms() async {
    if(api.token==null)return;
    final data=await api.request('GET','/api/dms');
    if(mounted)setState(()=>dms=List<Map<String,dynamic>>.from(data['threads'] as List));
  }
  Future<void> startDm() async {
    final username=await prompt('Nova mensagem privada','Nome do usuário');
    if(username==null||username.isEmpty)return;
    await perform(() async {
      final data=await api.request('POST','/api/dms',{'username':username});
      dmId=(data['thread'] as Map<String,dynamic>)['id'] as String;
      cursor=0;messages=[];
      await loadDms();await refresh();
      if(mounted&&MediaQuery.sizeOf(context).width<730)Navigator.pop(context);
    });
  }
  Future<void> createChannel(String type) async {
    if(serverId==null)return;
    final name=await prompt('Criar canal '+(type=='voice'?'de voz':'de texto'),'Nome do canal');
    if(name==null||name.isEmpty)return;
    await perform(() async {
      await api.request('POST','/api/servers/'+serverId!+'/channels',{'name':name,'type':type});
      await loadChannels();
    });
  }
  bool get canManage => servers.any((s)=>s['id']==serverId&&
    (s['role']=='owner'||s['role']=='moderator'));
  bool get isOwner => servers.any((s)=>s['id']==serverId&&s['role']=='owner');
  Future<void> manageMembers() async {
    if(serverId==null)return;
    await perform(() async {
      final selectedServer=serverId!;
      final result=await api.request('GET','/api/servers/'+selectedServer+'/members');
      if(!mounted)return;
      final members=List<Map<String,dynamic>>.from(result['members'] as List);
      await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
        title:const Text('Membros e cargos'),
        content:SizedBox(width:440,height:340,child:ListView(children:[
          for(final m in members) ListTile(
            title:Text(m['username'] as String),
            subtitle:Text(m['role'] as String),
            trailing:m['role']=='owner'?null:PopupMenuButton<String>(
              tooltip:'Gerenciar membro',
              onSelected:(action) async {
                Navigator.pop(ctx);
                await perform(() async {
                  final endpoint='/api/servers/'+selectedServer+'/members/'+(m['id'] as String);
                  if(action=='kick')await api.request('DELETE',endpoint);
                  else await api.request('PATCH',endpoint,{'role':action});
                  await loadServers();
                });
              },
              itemBuilder:(_)=>[
                if(isOwner)const PopupMenuItem(value:'moderator',child:Text('Tornar moderador')),
                if(isOwner)const PopupMenuItem(value:'member',child:Text('Tornar membro')),
                if(canManage)const PopupMenuItem(value:'kick',child:Text('Remover do servidor'))
              ]))
        ])),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Fechar'))]));
    });
  }

  Future<void> perform(Future<void> Function() task) async {
    setState(() {busy=true;error=null;});
    try {await task();} catch(e) {if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));}
    finally {if(mounted)setState(()=>busy=false);}
  }
  Future<void> authenticate()=>perform(() async {
    final data=await api.request('POST',signup?'/api/register':'/api/login',
      {'username':user.text.trim(),'password':password.text});
    api.token=data['token'] as String;
    nick=(data['user'] as Map<String,dynamic>)['username'] as String;
    password.clear();
    await storage.write(key:'veylor_session',value:api.token);
    await loadServers();await loadDms();startRealtime();
  });
  Future<void> loadServers() async {
    final r=await api.request('GET','/api/servers');
    servers=List<Map<String,dynamic>>.from(r['servers'] as List);
    if(!servers.any((s)=>s['id']==serverId))serverId=servers.isEmpty?null:servers.first['id'] as String;
    await loadChannels();
  }
  Future<void> loadChannels() async {
    channels=[];
    if(serverId!=null){
      final r=await api.request('GET','/api/servers/'+serverId!+'/channels');
      channels=List<Map<String,dynamic>>.from(r['channels'] as List);
    }
    if(!channels.any((c)=>c['id']==channelId&&c['type']=='text')){
      channelId=null;
      for(final c in channels){if(c['type']=='text'){channelId=c['id'] as String;break;}}
    }
    cursor=0; messages=[];
    if(dmId==null)await refresh();
    if(mounted)setState((){});
  }
  Future<void> refresh() async {
    final id=dmId??channelId;
    final isDm=dmId!=null;
    if(id==null||api.token==null)return;
    try {
      final route=isDm?'/api/dms/'+id+'/messages':'/api/channels/'+id+'/messages';
      final r=await api.request('GET',route+'?after='+cursor.toString());
      if(!mounted||id!=(isDm?dmId:channelId))return;
      final rows=List<Map<String,dynamic>>.from(r['messages'] as List);
      if(rows.isNotEmpty)setState((){messages.addAll(rows);cursor=rows.last['id'] as int;});
    }catch(e){if(mounted)setState(()=>error=e.toString());}
  }
  Future<void> send() async {
    final text=message.text.trim();
    if(text.isEmpty||(dmId==null&&channelId==null))return;
    await perform(() async {
      final route=dmId!=null?'/api/dms/'+dmId!+'/messages':'/api/channels/'+channelId!+'/messages';
      await api.request('POST',route,{'content':text});
      message.clear();await refresh();
    });
  }
  Future<String?> prompt(String title,String hint) async {
    final controller=TextEditingController();
    final result=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(title),content:TextField(controller:controller,autofocus:true,
        decoration:InputDecoration(hintText:hint)),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,controller.text.trim()),child:const Text('OK'))]));
    controller.dispose();return result;
  }
  Future<void> createServer() async {
    final name=await prompt('Criar servidor','Nome');
    if(name==null||name.isEmpty)return;
    await perform(() async {
      final r=await api.request('POST','/api/servers',{'name':name});
      serverId=(r['server'] as Map<String,dynamic>)['id'] as String;
      await loadServers();
    });
  }
  Future<void> joinInvite() async {
    final code=await prompt('Entrar no servidor','Código de convite');
    if(code==null||code.isEmpty)return;
    await perform(() async {
      final r=await api.request('POST','/api/invites/'+Uri.encodeComponent(code)+'/join');
      serverId=r['server_id'] as String;
      await loadServers();
    });
  }
  Future<void> invite() async {
    if(serverId==null)return;
    await perform(() async {
      final r=await api.request('POST','/api/servers/'+serverId!+'/invites');
      if(!mounted)return;
      await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
        title:const Text('Convite válido por 7 dias'),
        content:SelectableText(r['code'] as String),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Fechar'))]));
    });
  }
  Future<void> voice(Map<String,dynamic> c) async {
    await perform(() async {
      await api.request('POST','/api/media/token',{'channel_id':c['id']});
      if(!mounted)return;
      await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
        title:const Text('Mídia ainda não ativada'),
        content:const Text('O backend autorizou o canal. O cliente de voz e vídeo LiveKit será integrado na próxima versão.'),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Entendi'))]));
    });
  }
  Widget rails() => Row(children:[
    Container(width:70,color:sidebar,child:Column(children:[
      const Padding(padding:EdgeInsets.all(12),child:Icon(Icons.bubble_chart,color:accent,size:34)),
      Expanded(child:ListView(children:[
        for(final s in servers) Padding(padding:const EdgeInsets.all(6),
          child:Tooltip(message:s['name'] as String,child:InkWell(
            onTap:()=>perform(() async {dmId=null;serverId=s['id'] as String;await loadChannels();}),
            child:Container(height:50,alignment:Alignment.center,
              decoration:BoxDecoration(color:serverId==s['id']?accent:surface,
                borderRadius:BorderRadius.circular(17)),
              child:Text((s['name'] as String).substring(0,1).toUpperCase(),
                style:const TextStyle(fontSize:21,fontWeight:FontWeight.bold)))))),
        IconButton(tooltip:'Criar servidor',onPressed:createServer,icon:const Icon(Icons.add_circle_outline)),
        IconButton(tooltip:'Entrar com convite',onPressed:joinInvite,icon:const Icon(Icons.login)),
      ]))])),
    Expanded(child:Container(color:surface,child:Column(children:[
      ListTile(title:Text(servers.where((s)=>s['id']==serverId).map((s)=>s['name'] as String)
        .firstOrNull??'Veylor',maxLines:1,overflow:TextOverflow.ellipsis),
        trailing:IconButton(tooltip:'Convite',onPressed:invite,icon:const Icon(Icons.person_add))),
      const Divider(height:1),
      ListTile(title:const Text('MENSAGENS PRIVADAS',style:TextStyle(fontSize:11,color:Colors.white54)),
        trailing:IconButton(icon:const Icon(Icons.add,size:19),tooltip:'Nova DM',onPressed:startDm)),
      for(final d in dms)
        ListTile(dense:true,leading:const Icon(Icons.person_outline,size:19),
          title:Text(d['username'] as String),selected:dmId==d['id'],
          onTap:()=>perform(() async {
            dmId=d['id'] as String;cursor=0;messages=[];await refresh();
            if(mounted&&MediaQuery.sizeOf(context).width<730)Navigator.pop(context);
          })),
      ListTile(title:const Text('CANAIS DE TEXTO',style:TextStyle(fontSize:11,color:Colors.white54)),
        trailing:canManage?IconButton(icon:const Icon(Icons.add,size:19),tooltip:'Criar texto',
          onPressed:()=>createChannel('text')):null),
      for(final c in channels.where((c)=>c['type']=='text'))
        ListTile(dense:true,leading:const Icon(Icons.tag,size:18),title:Text(c['name'] as String),
          selected:channelId==c['id'],
          onTap:()=>perform(() async {
            dmId=null;channelId=c['id'] as String;cursor=0;messages=[];await refresh();
            if(mounted&&MediaQuery.sizeOf(context).width<730)Navigator.pop(context);
          })),
      ListTile(title:const Text('CANAIS DE VOZ',style:TextStyle(fontSize:11,color:Colors.white54)),
        trailing:canManage?IconButton(icon:const Icon(Icons.add,size:19),tooltip:'Criar voz',
          onPressed:()=>createChannel('voice')):null),
      for(final c in channels.where((c)=>c['type']=='voice'))
        ListTile(dense:true,leading:const Icon(Icons.volume_up_outlined,size:18),
          title:Text(c['name'] as String),onTap:()=>voice(c)),
      const Spacer(),
      ListTile(leading:const Icon(Icons.groups_2_outlined),title:const Text('Membros'),onTap:manageMembers),
      Container(color:sidebar,child:ListTile(
        leading:const CircleAvatar(backgroundColor:accent,child:Icon(Icons.person)),
        title:Text(nick??'Conta'),subtitle:Text(realtime?'V0.2 • Online':'V0.2 • Reconectando'),
        trailing:IconButton(tooltip:'Sair',icon:const Icon(Icons.logout),onPressed:() async {
          polling?.cancel();retrySocket?.cancel();
          try{await api.request('POST','/api/logout');}catch(_){}
          api.token=null;socket?.close();socket=null;
          try{await storage.delete(key:'veylor_session');}catch(_){}
          if(mounted)setState((){nick=null;serverId=null;dmId=null;realtime=false;servers=[];channels=[];dms=[];messages=[];});
        })))
    ]))))
  ]);
  Widget chat() {
    final name=dmId!=null?(dms.where((d)=>d['id']==dmId).map((d)=>d['username'] as String).firstOrNull??'DM'):
      (channels.where((c)=>c['id']==channelId).map((c)=>c['name'] as String).firstOrNull??'geral');
    return Column(children:[
      SizedBox(height:58,child:Row(children:[
        if(MediaQuery.sizeOf(context).width<730)
          Builder(builder:(ctx)=>IconButton(onPressed:()=>Scaffold.of(ctx).openDrawer(),
            icon:const Icon(Icons.menu))),
        const SizedBox(width:15),Icon(dmId!=null?Icons.person_outline:Icons.tag,color:Colors.white54),
        const SizedBox(width:8),Text(name,style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
        const SizedBox(width:10),Icon(realtime?Icons.wifi:Icons.wifi_off,size:15,color:realtime?Colors.greenAccent:Colors.orangeAccent),
        const Spacer(),IconButton(tooltip:'Atualizar',onPressed:refresh,icon:const Icon(Icons.refresh))
      ])),
      const Divider(height:1),
      Expanded(child:ListView.builder(padding:const EdgeInsets.all(20),
        itemCount:messages.length+1,itemBuilder:(ctx,i){
          if(i==0)return Padding(padding:const EdgeInsets.only(bottom:22),
            child:Text('Bem-vindo '+(dmId!=null?'à conversa com ':'a #')+name,style:const TextStyle(fontSize:23,fontWeight:FontWeight.bold)));
          final m=messages[i-1];
          return Padding(padding:const EdgeInsets.symmetric(vertical:9),child:Row(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
              CircleAvatar(radius:18,backgroundColor:accent,
                child:Text((m['username'] as String)[0].toUpperCase())),
              const SizedBox(width:12),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(m['username'] as String,style:const TextStyle(fontWeight:FontWeight.bold)),
                const SizedBox(height:3),SelectableText(m['content'] as String)
              ]))
            ]));
        })),
      if(error!=null)Text(error!,style:const TextStyle(color:Colors.orangeAccent)),
      Padding(padding:const EdgeInsets.all(14),child:Row(children:[
        Expanded(child:TextField(controller:message,maxLines:4,minLines:1,
          onSubmitted:(_)=>send(),decoration:InputDecoration(hintText:dmId!=null?'Mensagem para '+name:'Mensagem em #'+name))),
        const SizedBox(width:8),
        IconButton.filled(onPressed:busy?null:send,icon:const Icon(Icons.send))
      ]))
    ]);
  }
  Widget auth() => Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:420),
    child:Padding(padding:const EdgeInsets.all(24),child:Column(
      mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const Icon(Icons.bubble_chart_rounded,color:accent,size:65),
        const SizedBox(height:20),
        Text(signup?'Criar conta Veylor':'Bem-vindo ao Veylor',
          textAlign:TextAlign.center,style:const TextStyle(fontSize:27,fontWeight:FontWeight.bold)),
        const SizedBox(height:24),
        TextField(controller:user,decoration:const InputDecoration(labelText:'Usuário')),
        const SizedBox(height:14),
        TextField(controller:password,obscureText:true,
          onSubmitted:(_)=>authenticate(),decoration:const InputDecoration(labelText:'Senha')),
        const SizedBox(height:20),
        FilledButton(onPressed:busy?null:authenticate,
          child:Padding(padding:const EdgeInsets.all(12),child:Text(signup?'Cadastrar':'Entrar'))),
        TextButton(onPressed:()=>setState(()=>signup=!signup),
          child:Text(signup?'Já tenho conta':'Criar conta')),
        if(error!=null)Text(error!,textAlign:TextAlign.center,
          style:const TextStyle(color:Colors.orangeAccent)),
        const SizedBox(height:12),
        const Text('Veylor V0.2 • DMs, WebSocket e permissões',textAlign:TextAlign.center)
      ]))));
  @override
  Widget build(BuildContext context){
    if(restoring)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    if(api.token==null)return Scaffold(body:auth());
    final mobile=MediaQuery.sizeOf(context).width<730;
    return Scaffold(
      drawer:mobile?Drawer(width:335,child:rails()):null,
      body:Row(children:[if(!mobile)SizedBox(width:315,child:rails()),Expanded(child:chat())]));
  }
}
