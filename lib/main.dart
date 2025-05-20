import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:audiotagger/audiotagger.dart';
import 'package:audiotagger/models/tag.dart';
import 'dart:typed_data';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDarkMode = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
        textTheme: Theme.of(context).textTheme.apply(bodyColor: Colors.black),
      ),
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Color(0xFF0F172A),
        textTheme: Theme.of(context).textTheme.apply(bodyColor: Colors.white),
      ),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: MusicHomeScreen(
        isDarkMode: isDarkMode,
        onToggleTheme: () {
          setState(() {
            isDarkMode = !isDarkMode;
          });
        },
      ),
    );
  }
}

class MusicHomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const MusicHomeScreen({
    Key? key,
    required this.isDarkMode,
    required this.onToggleTheme,
  }) : super(key: key);

  @override
  _MusicHomeScreenState createState() => _MusicHomeScreenState();
}

class _MusicHomeScreenState extends State<MusicHomeScreen> {
  final AudioPlayer _player = AudioPlayer();
  final tagger = Audiotagger();
  bool isPlaying = false;
  String currentTitle = "Sample MP3";
  String currentArtist = "Local File";
  List<File> musicFiles = [];
  Uint8List? coverImage;

  @override
  void initState() {
    super.initState();
    _loadMusicFiles();
  }

  Future<void> _loadMusicFiles() async {
    final status = await Permission.storage.request();
    if (!status.isGranted) return;

    final directory = Directory('/storage/emulated/0/Music');
    if (await directory.exists()) {
      final files =
          directory
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.mp3'))
              .toList();
      setState(() {
        musicFiles = files;
      });
    }
  }

  Future<void> _playFile(File file) async {
    await _player.setFilePath(file.path);
    _player.play();

    final Tag? tags = await tagger.readTags(path: file.path);
    Uint8List? art;
    try {
      art = await tagger.readArtwork(path: file.path);
    } catch (_) {}

    setState(() {
      isPlaying = true;
      currentTitle = tags?.title ?? p.basenameWithoutExtension(file.path);
      currentArtist = tags?.artist ?? "Unknown Artist";
      coverImage = art;
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = isDark ? Color(0xFF1E293B) : Colors.grey[300];
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(backgroundColor: Colors.grey, radius: 20),
                  Text(
                    'Home',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          widget.isDarkMode
                              ? Icons.light_mode
                              : Icons.dark_mode,
                          color: textColor,
                        ),
                        onPressed: widget.onToggleTheme,
                      ),
                      Icon(Icons.search, color: textColor),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child:
                          coverImage != null
                              ? Image.memory(
                                coverImage!,
                                height: 60,
                                width: 60,
                                fit: BoxFit.cover,
                              )
                              : Image.asset(
                                'assets/cover1.jpg',
                                height: 60,
                                width: 60,
                                fit: BoxFit.cover,
                              ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentTitle,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            currentArtist,
                            style: TextStyle(color: textColor.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                        size: 36,
                        color: Color(0xFF60A5FA),
                      ),
                      onPressed: () async {
                        if (_player.playing) {
                          await _player.pause();
                        } else {
                          if (musicFiles.isNotEmpty) {
                            _playFile(musicFiles.first);
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Text(
                'All Music Files',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: musicFiles.length,
                  itemBuilder: (context, index) {
                    final file = musicFiles[index];
                    return ListTile(
                      leading: Icon(Icons.music_note, color: textColor),
                      title: Text(
                        p.basenameWithoutExtension(file.path),
                        style: TextStyle(color: textColor),
                      ),
                      onTap: () => _playFile(file),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
