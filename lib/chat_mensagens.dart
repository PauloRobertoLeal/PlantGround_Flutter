import 'dart:io' as io;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(MaterialApp(
    title: 'Chat Mensagens',
    debugShowCheckedModeBanner: false,
  ));
}

final ThemeData kIOSTheme = ThemeData(
    primarySwatch: Colors.orange,
    primaryColor: Colors.grey[100],
    primaryColorBrightness: Brightness.light);

final ThemeData kDefaultTheme = ThemeData(
  primarySwatch: Colors.purple,
  accentColor: Colors.orangeAccent[400],
);

final googleSignIn = GoogleSignIn();
final auth = FirebaseAuth.instance;
var _currentUser;

Future<Null> _ensureLoggedIn() async {
  GoogleSignInAccount user = googleSignIn.currentUser;
  _currentUser = user;
  if (user == null){
    user = await googleSignIn.signInSilently();
  }

  if (user == null){
    user = await googleSignIn.signIn();
  }
  
  if (await auth.currentUser() == null){
    GoogleSignInAuthentication credentials = await googleSignIn.currentUser.authentication;
    await auth.signInWithCredential(GoogleAuthProvider.getCredential(
        idToken: credentials.idToken, accessToken: credentials.accessToken));
  }
}

_handleSubmitted(String text) async {
  await _ensureLoggedIn();
  _sendMessage(text: text);
}

void _sendMessage({String text, String imgUrl}) {
  Firestore.instance.collection("mensagens").add({
    "text": text,
    "imgUrl": imgUrl,
    "senderName": _currentUser.toString(),
    "senderPhotoUrl": "googleSignIn.currentUser.photoUrl"
  });
}

class ChatMensagem extends StatefulWidget {
  ChatMensagem({Key key}) : super(key: key);

  @override
  _ChatMensagemState createState() => _ChatMensagemState();
}

class _ChatMensagemState extends State<ChatMensagem> {
  @override
  Widget build(BuildContext context) {
    return Container(
        child: SafeArea(
            bottom: false,
            top: false,
            child: Scaffold(
                appBar: AppBar(
                  backgroundColor: Colors.greenAccent,
                  title: Text("PlantGround"),
                  centerTitle: true,
                  elevation: Theme.of(context).platform == TargetPlatform.iOS
                      ? 0.0
                      : 4.0,
                ),
                body: Column(
                  children: <Widget>[
                    Expanded(
                      child: StreamBuilder(
                        stream: Firestore.instance
                            .collection("mensagens")
                            .snapshots(),
                        builder: (context, snapshot) {
                          switch (snapshot.connectionState) {
                            case ConnectionState.none:
                            case ConnectionState.waiting:
                              return Center(
                                child: CircularProgressIndicator(),
                              );
                            default:
                              return ListView.builder(
                                reverse: true,
                                itemCount: snapshot.data.documents.length,
                                itemBuilder: (context, index) {
                                  List r = snapshot.data.documents.reversed.toList();
                                  return Message(r[index].data);
                                },
                              );
                          }
                        },
                      ),
                    ),
                    Divider(
                      height: 1.0,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                      ),
                      child: TextComposer(),
                    )
                  ],
                ))));
  }
}

class TextComposer extends StatefulWidget {
  TextComposer({Key key}) : super(key: key);

  @override
  _TextComposerState createState() => _TextComposerState();
}

class _TextComposerState extends State<TextComposer> {
  final _textController = TextEditingController();
  bool _isComposing = false;

  void _reset() {
    _textController.clear();
    setState(() {
      _isComposing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).accentColor),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        decoration: Theme.of(context).platform == TargetPlatform.iOS
            ? BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200])))
            : null,
        child: Row(
          children: <Widget>[
            Container(
              child: IconButton(
                icon: Icon(Icons.photo_camera),
                onPressed: () async {
                  await _ensureLoggedIn();
                  io.File imgFile = await ImagePicker.pickImage(source: ImageSource.camera);
                  if (imgFile == null) return;
                  StorageUploadTask task = FirebaseStorage.instance.ref().
                    child(googleSignIn.currentUser.id.toString() +
                      DateTime.now().millisecondsSinceEpoch.toString()).putFile(imgFile);
                  StorageTaskSnapshot snap = await task.onComplete;
                        _sendMessage(imgUrl: await snap.ref.getDownloadURL());
                      }),
            ),
            Expanded(
              child: TextField(
                  controller: _textController,
                  decoration: InputDecoration.collapsed(
                      hintText: "Enviar uma Mensagem"),
                  onChanged: (text) {
                    setState(() {
                      _isComposing = text.length > 0;
                    });
                  },
                  onSubmitted: (text) {
                    _handleSubmitted(_textController.text);
                    _reset();
                  }),
            ),
            Container(
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Theme.of(context).platform == TargetPlatform.iOS
                    ? CupertinoButton(
                        child: Text("Enviar"),
                        onPressed: _isComposing
                            ? () {
                                _handleSubmitted(_textController.text);
                                _reset();
                              }
                            : null,
                      )
                    : IconButton(
                        icon: Icon(Icons.send),
                        onPressed: _isComposing
                            ? () {
                                _handleSubmitted(_textController.text);
                                _reset();
                              }
                            : null,
                      ))
          ],
        ),
      ),
    );
  }
}

class Message extends StatelessWidget {
  final Map<String, dynamic> data;

  Message(this.data);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              margin: const EdgeInsets.only(right: 16.0),
              child: CircleAvatar(
                backgroundImage: NetworkImage(data["senderPhotoUrl"]),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(data["senderName"],
                      style: Theme.of(context).textTheme.subhead),
                  Container(
                      margin: const EdgeInsets.only(top: 5.0),
                      child: data["imgUrl"] != null
                          ? Image.network(data["imgUrl"], width: 250.0)
                          : Text(data["text"]))
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}