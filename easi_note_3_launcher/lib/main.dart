import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ffi' hide Size;
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:window_manager/window_manager.dart';

final logFile = File('launcher_log.log');

void main(List<String> args) async {
  if (await isSelfAlreadyRunning()) exit(0);

  if (await isProcessRunning("EasiNote.exe")) {
    await Process.start("EasiRunner.exe", []);
    exit(0);
  }

  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions options = const WindowOptions(
    size: Size(700, 314),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );

  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.hide();
    await windowManager.setAsFrameless();
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(LauncherApp(args: args));
}


class LauncherApp extends StatelessWidget {
  final List<String> args;
  const LauncherApp({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SplashScreen(args: args),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  final List<String> args;
  const SplashScreen({super.key, required this.args});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final bool _debugMode = false; // 开发时 true，发布时 false
  String logText = "";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();

    _controller.addStatusListener((status) async {
      if (status == AnimationStatus.completed) {
        var process = await Process.start(
            await extractCdb(),
          [
            "-g",
            "-G",
            "-o",
            r'''C:\Users\Administrator\Desktop\EasiNoteSetup_3.1.2.3606\Main\'''+"EasiNote.exe",
            ...widget.args,
          ],
          workingDirectory: File(Platform.resolvedExecutable).parent.path
        );

        process.stdout.listen((data) {
          final text = systemEncoding.decode(data);
          log("cdb stdout: $text");
          setState(() {
            logText = text;
          });
        });

        process.stderr.listen((data) {
          final text = systemEncoding.decode(data);
          log("cdb stderr: $text");
          setState(() {
            logText = text;
          });
        });

        await Future.delayed(const Duration(seconds: 5), () async {
          process.stdin.writeln(".detach");
          await Future.delayed(const Duration(seconds: 1));
          process.stdin.writeln("q");
          await Future.delayed(const Duration(seconds: 1));
          exit(0);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.2)),
        child: Container(
          decoration: BoxDecoration( color: Colors.black, border: Border.all( color: Colors.white38, width: 1.5, ), ),
          child: Stack(
            clipBehavior: Clip.antiAlias,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SlideTransition(
                        position: Tween<Offset>(begin: const Offset(-0.1, 0), end: Offset.zero)
                            .animate(CurvedAnimation(parent: _controller, curve: const Interval(0.1, 1, curve: Curves.fastOutSlowIn, ),)),
                        child: FadeTransition(
                          opacity: CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 56, left: 56, right: 48),
                            child: Transform.translate(
                              offset: const Offset(0, 18),
                              child: Image.asset("assets/xxyxxdmc.png", scale: 3.2,),
                            ),
                          ),
                        ),
                      ),
                      SlideTransition(
                        position: Tween<Offset>(begin: const Offset(-0.11, 0), end: Offset.zero)
                            .animate(CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn)),
                        child: FadeTransition(
                          opacity: CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 48),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "EN3 Launcher",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontFamily: "Minecraft",
                                    shadows: [
                                      Shadow(offset: Offset(2, 2), color: Colors.white12),
                                    ],
                                  ),
                                ),
                                Text(
                                  "Made with xXYxxdMC",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontFamily: "Minecraft",
                                    shadows: [
                                      Shadow(offset: Offset(2, 2), color: Colors.white12),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  "Launching...",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontFamily: "Minecraft",
                                    shadows: [
                                      Shadow(offset: Offset(2, 2), color: Colors.white12),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    ],
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (i) {
                      return TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: Duration(milliseconds: 2000 + i * 500),
                        curve: DotCurve(),
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(((value - 0.5) * 800) + i * 20, 0),
                            child: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: CircleAvatar(radius: 3, backgroundColor: Colors.white),
                            ),
                          );
                        },
                      );
                    }),
                  ),
                ],
              ),
              FadeTransition(
                opacity: CurvedAnimation(parent: _controller, curve: const Interval(0.7, 1.0)),
                child: Stack(
                  children: [
                    Image.asset("assets/welcome_background.png"),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Align(alignment: Alignment.bottomCenter, child: Container(
                        width: 400,
                        child: Text(
                          logText,
                          style: const TextStyle(
                            color: Color(0xFF98c557),
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      )
                        ,),
                    )
                  ],
                ),
              )
            ],
          )
        ),
      ),
    );
  }
}

class DotCurve extends Curve {
  @override
  double transform(double t) {
    final cubic = pow(2*t - 1, 3);
    return (0.7 * cubic + 0.3 * (2*t - 1) + 0.5).clamp(0.0, 1.0);
  }
}

void log(String message) {
  final time = DateTime.now().toIso8601String();
  logFile.writeAsStringSync("[$time] $message\n", mode: FileMode.append);
  debugPrint("[$time] $message");
}

final _kernel32 = DynamicLibrary.open('kernel32.dll');

final CreateMutexW = _kernel32.lookupFunction<
    IntPtr Function(Pointer<Void>, Int32, Pointer<Utf16>),
    int Function(Pointer<Void>, int, Pointer<Utf16>)
>('CreateMutexW');

Future<bool> isSelfAlreadyRunning() async {
  final exeName = Platform.resolvedExecutable.split(Platform.pathSeparator).last;

  final result = await Process.run('tasklist', []);
  if (result.exitCode != 0) {
    return false;
  }

  final output = result.stdout.toString().toLowerCase();

  final count = RegExp(exeName.toLowerCase()).allMatches(output).length;

  return count > 1;
}

Future<bool> isProcessRunning(String exeName) async {
  final result = await Process.run('tasklist', []);
  if (result.exitCode != 0) {
    return false;
  }
  final output = result.stdout.toString().toLowerCase();
  return output.contains(exeName.toLowerCase());
}

Future<String> extractCdb() async {
  final bytes = await rootBundle.load('assets/cdb.exe');
  final tempDir = Directory.systemTemp.path;
  final exePath = path.join(tempDir, 'cdb.exe');
  final file = File(exePath);
  await file.writeAsBytes(bytes.buffer.asUint8List());
  return exePath;
}
