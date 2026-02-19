import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:easi_note_3_launcher/setting.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:window_manager/window_manager.dart';

final logFile = File('launcher_log.log');

final processId = randomString(12);

bool isTampered = false;

bool settingMode = false;

bool launched = false;

late bool noAnim;

late bool fastBoot;

bool installMode = false;

RandomAccessFile? file;

void main(List<String> args) async {
  Timer.periodic(
    const Duration(seconds: 5), (timer) {
      if (!launched) {
        exit(1);
      } else {
        timer.cancel();
      }
    },
  );
  file = await startLock();
  log("锁已显现");
  await recordLaunchAndCheckSettingMode();
  log("文已铭记");

  if (await isProcessRunning() && !settingMode) {
    await Process.start("EasiRunner.exe", []);
    allExit(0);
  }

  WidgetsFlutterBinding.ensureInitialized();
  log("组以相连");

  if (!settingMode) {
    try {
      await verifyAssets();
    } catch (_) {
      isTampered = true;
      log("其资者损");
    }
  }

  if (!await File("EasiNote.exe").exists()) {
    installMode = true;
    log("其本则没");
  }

  noAnim = await Settings.getNoAnimation();
  log("无灵动之迹");

  fastBoot = await Settings.getFastboot();
  log("无长繁之载");

  await clearLogFile();
  log("扫赘余");
  await extractTtf();
  log("解表象");

  await windowManager.ensureInitialized();
  log("初窗");

  WindowOptions options = WindowOptions(
    size: Size(700, 310 + ((settingMode && !isTampered) || installMode ? 60 : 0)),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );
  log("构架");

  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.hide();
    await windowManager.setAsFrameless();
    await windowManager.show();
    await windowManager.focus();
  });
  log("亦待其显现");

  launched = true;
  runApp(LauncherApp(args: args));
  log("成形其灵体");
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
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late RotationManager manager;
  final ValueNotifier<double> tempAngle = ValueNotifier(0.0);
  String logText = "";
  bool pressed = false;
  bool pressedFix = false;
  bool isLoading = false;
  bool _exiting = false;
  bool injectDone = false;
  bool isRunning = false;
  ValueNotifier<int> clrCount = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward(from: (noAnim && !isTampered) ? 0.7 : 0);

    if (fastBoot && !isTampered && !settingMode && !installMode) startEasiNote();

    manager = RotationManager(this);

    if (!isTampered && !settingMode && !installMode) {
      _controller.addStatusListener((status) async {
        if (status == AnimationStatus.completed) startEasiNote();
      });
    }
  }

  Future<void> startEasiNote() async {
    var process = await Process.start(
        await extractCdb(),
        [
          "-g",
          "-G",
          "-o",
          "EasiNote.exe",
          ...widget.args,
        ],
        workingDirectory: File(Platform.resolvedExecutable).parent.path
    );

    process.stdout.listen((data) {
      final text = systemEncoding.decode(data);
      log("cdb stdout: $text");
      if (text.contains("CLR exception")) clrCount.value++;
      setState(() {
        logText = text;
      });
    });

    process.stderr.listen((data) {
      final text = systemEncoding.decode(data);
      log("cdb stderr: $text");
      if (text.contains("CLR exception")) clrCount.value++;
      setState(() {
        logText = text;
      });
    });

    clrCount.addListener(() async {
      if (!_exiting && clrCount.value >= 2) {
        safeExit(process);
      }
    });

    Timer(const Duration(seconds: 20), () async {
      safeExit(process);
    });

    await process.exitCode;

    safeExit(process);
  }

  void safeExit(Process process) async {
    if (!_exiting) {
      _exiting = true;
      process.stdin.writeln(".detach");
      await process.stdin.flush();
      process.stdin.writeln("q");
      await process.stdin.flush();
      allExit(0);
    }
  }

  double progress = 0.0;
  double progress1 = 0.0;
  double progress2 = 0.0;
  double progress3 = 0.0;
  String status = "未开始";

  Future<void> downloadFile(String url, {int index = 0}) async {
    final dir = await getApplicationCacheDirectory();
    final savePath = "${dir.path}/chunk_$index.exe";

    const maxRetries = 5;
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        status = "正在连接服务器 (第 ${attempt + 1} 次尝试)...";
        log(status);
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 250));

        final total = switch(index) {
          0 => 96468992,
          1 => 96468992,
          2 => 96468992,
          3 => 95265000,
          _ => -1
        };
        log("文件总大小: $total 字节");

        final process = await Process.start(
          'curl',
          [
            '-L',
            '-b',
            '',
            '-c',
            '/dev/null/',
            '-A',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                'AppleWebKit/537.36 (KHTML, like Gecko) '
                'Chrome/144.0.0.0 Safari/537.36 Edg/144.0.0.0',
            '-H',
            'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            '-H',
            'Accept-Encoding: gzip, deflate, br, zstd',
            '-H',
            'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8',
            '-H',
            'Connection: keep-alive',
            '-H',
            'Host: ${Uri.parse(url).host}',
            url,
            '-o',
            savePath,
          ],
          runInShell: true,
        );

        process.stderr.transform(SystemEncoding().decoder).listen((data) {
          if (total > 0) {
            final downloaded = File(savePath).existsSync()
                ? File(savePath).lengthSync()
                : 0;
            switch (index) {
              case 0:
                progress = downloaded / total * 100;
                break;
              case 1:
                progress1 = downloaded / total * 100;
                break;
              case 2:
                progress2 = downloaded / total * 100;
                break;
              case 3:
                progress3 = downloaded / total * 100;
                break;
            }
            status = "正在接收数据 - ${((progress + progress1 + progress2 + progress3) / 4).toStringAsFixed(3)}%";
            setState(() {});
            log(status);
          } else {
            status = "正在接收数据 (未知总大小)...";
            setState(() {});
            log(status);
          }
        });

        final exitCode = await process.exitCode;
        if (exitCode == 0) {
          status = "下载完成，文件已保存到: $savePath";
          setState(() {});
          log(status);
          break;
        } else {
          throw Exception("curl 退出码: $exitCode");
        }
      } catch (e) {
        attempt++;
        status = "下载失败 (第 $attempt 次): $e";
        setState(() {});
        log(status);

        if (attempt >= maxRetries) {
          status = "已达到最大重试次数，下载终止";
          setState(() {});
          log(status);
        } else {
          status = "准备重试...";
          setState(() {});
          log(status);
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
  }

  String? rawPath;

  Future<String?> findEasiNote() async {
    final drives = ['C', 'D', 'E', 'F'];

    final candidates = [
      r'Program Files (x86)\Seewo\EasiNote\Main',
      r'Program Files\Seewo\EasiNote\Main',
      r'Seewo\EasiNote\Main',
      r'Main',
    ];

    if (rawPath != null) {
      for (final candidate in candidates) {
        final path = "$rawPath\\$candidate";
        if (await Directory(path).exists() && await File("$path\\EasiNote.exe").exists()) {
          return path;
        }
      }
    }

    for (final drive in drives) {
      for (final candidate in candidates) {
        final path = "$drive:\\$candidate";
        if (await Directory(path).exists() && await File("$path\\EasiNote.exe").exists()) {
          return path;
        }
      }
    }
    return null;
  }

  Future<void> injectSelf(String path) async {
    final currentPath = File(Platform.resolvedExecutable).parent.path;
    status = "正在注入...";
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 250));
    final app = File("$currentPath/EasiNote3Launcher.exe");
    final flutterDll = File("$currentPath/flutter_windows.dll");
    final screenDll = File("$currentPath/screen_retriever_windows_plugin.dll");
    final windowManagerDll = File("$currentPath/window_manager_plugin.dll");
    final dataDirectory = Directory("$currentPath/data");
    final targetDataDir = Directory("$path/data");

    status = "正在注入主程序...";
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 250));
    await app.copy("$path\\EasiNote3Launcher.exe");
    status = "正在注入DLL...";
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 250));
    await flutterDll.copy("$path\\flutter_windows.dll");
    await screenDll.copy("$path\\screen_retriever_windows_plugin.dll");
    await windowManagerDll.copy("$path\\window_manager_plugin.dll");
    status = "正在注入数据...";
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 250));
    await copyDirectory(dataDirectory, targetDataDir);
    status = "注入完成";
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 250));
  }

  Future<void> copyDirectory(Directory source, Directory destination) async {
    if (!await destination.exists()) {
      await destination.create(recursive: true);
    }

    await for (var entity in source.list(recursive: true)) {
      final relativePath = path.relative(entity.path, from: source.path);
      final newPath = path.join(destination.path, relativePath);

      if (entity is File) {
        await File(entity.path).copy(newPath);
      } else if (entity is Directory) {
        await Directory(newPath).create(recursive: true);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.2)),
        child: Container(
          width: 697,
          height: 311 + ((settingMode && !isTampered) || installMode ? 60 : 0),
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: Colors.white38, width: 1.5,),
          ),
          child: (!settingMode && !installMode) || isTampered ? Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              FutureBuilder(future: Settings.getNoAnimation(), builder: (_, snapshot,) {
                final data = snapshot.data ?? false;
                return (data && !isTampered) ? SizedBox.shrink() : Column(
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
                              padding: EdgeInsets.only(top: 56, left: 48, right: 56 + (isTampered ? 72 : 0)),
                              child: Transform.translate(
                                offset: const Offset(0, 18),
                                child: isTampered ? Icon(Icons.warning_amber, color: Colors.white, size: 200) : Image.asset("assets/eHh5eHhkbWMucG5n", scale: 3.2,),
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
                              padding: EdgeInsets.only(right: 48 + (isTampered ? 64 : 0)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isTampered ? "启动出错" : "EN3 Launcher",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontFamily: isTampered ? null : "Minecraft",
                                      shadows: const [
                                        Shadow(offset: Offset(2, 2), color: Colors.white12),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    isTampered ? "资源文件被篡改" : "Made with xXYxxdMC",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontFamily: isTampered ? null : "Minecraft",
                                      shadows: const [
                                        Shadow(offset: Offset(2, 2), color: Colors.white12),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  !isTampered ? Text(
                                    "Launching...",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontFamily: "Minecraft",
                                      shadows: [
                                        Shadow(offset: Offset(2, 2), color: Colors.white12),
                                      ],
                                    ),
                                  ) : ElevatedButton.icon(onPressed: () {
                                    allExit(0);
                                  }, label: Text("退出", style: const TextStyle(color: Colors.black),), icon: Icon(Icons.logout),
                                    style: ElevatedButton.styleFrom(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.all(Radius.circular(4)))
                                    ),),
                                ],
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
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
                );
              }),
              if (!isTampered) FadeTransition(
                opacity: CurvedAnimation(parent: _controller, curve: const Interval(0.7, 1.0)),
                child: Stack(
                  children: [
                    Image.asset("assets/d2VsY29tZV9iYWNrZ3JvdW5kLnBuZw=="),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Align(alignment: Alignment.bottomCenter, child: SizedBox(
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
          ) : !installMode ? Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Center(
                child: ValueListenableBuilder<double>(
                  valueListenable: tempAngle,
                  builder: (context, extraAngle, child) {
                    return AnimatedBuilder(
                      animation: manager.baseController,
                      builder: (context, child) {
                        final angle = manager.baseController.value * 2 * 3.1415926 + extraAngle;
                        return Transform.rotate(angle: angle, child: child);
                      },
                      child: child,
                    );
                  },
                  child: AnimatedScale(
                    scale: 1 + (isLoading ? 0.5 : 0),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.fastOutSlowIn,
                    child: const Icon(
                      Icons.settings,
                      size: 256,
                      color: Color(0x37FFFFFF),
                    ),
                  ),
                )
              ),
              Center(
                child: ClipRect(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: isLoading ? 0 : 8, end: isLoading ? 8 : 0),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.fastOutSlowIn,
                    builder: (_, value, _) {
                      return BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: value,
                          sigmaY: value,
                        ),
                        child: Padding(padding: const EdgeInsets.all(32), child: SizedBox.expand(),),
                      );
                    },
                  ),
                ),
              ),
              Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  title: Text("设置", style: TextStyle(color: Colors.white),),
                  centerTitle: true,
                  backgroundColor: Colors.transparent,
                  actions: [
                    IconButton(onPressed: () {
                      allExit(0);
                    }, icon: Icon(Icons.close, color: Colors.white,)),
                    const SizedBox(width: 8,)
                  ],
                ),
                body: Padding(padding: const EdgeInsets.only(left: 32, right: 32), child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Icon(Icons.fast_forward, color: Colors.white, size: 48,),
                        const SizedBox(width: 8,),
                        Text("快速启动", style: TextStyle(color: Colors.white, fontSize: 24),),
                        SizedBox(width: 16,),
                        FutureBuilder<bool>(
                          future: Settings.getFastboot(),
                          builder: (context, snapshot) {
                            final value = snapshot.data ?? false;
                            return Switch(
                              value: value,
                              activeThumbColor: Colors.black,
                              activeTrackColor: Colors.white,
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: Colors.black,
                              onChanged: (v) async {
                                await Settings.setFastboot(v);
                                manager.triggerFastSpin(this, (v) {
                                  setState(() {
                                    tempAngle.value = v;
                                  });
                                });
                                setState(() {});
                              },
                            );
                          },
                        )
                      ],
                    ),
                    const SizedBox(height: 16,),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Icon(Icons.animation, color: Colors.white, size: 48,),
                        const SizedBox(width: 8,),
                        Text("移除启动动画", style: TextStyle(color: Colors.white, fontSize: 24),),
                        SizedBox(width: 16,),
                        FutureBuilder<bool>(
                          future: Settings.getNoAnimation(),
                          builder: (context, snapshot) {
                            final value = snapshot.data ?? false;
                            return Switch(
                              value: value,
                              activeThumbColor: Colors.black,
                              activeTrackColor: Colors.white,
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: Colors.black,
                              onChanged: (v) async {
                                setState(() {
                                  isLoading = true;
                                });
                                await Settings.setNoAnimation(v);
                                manager.triggerFastSpin(this, (v) {
                                  setState(() {
                                    tempAngle.value = v;
                                  });
                                });
                                setState(() {
                                  isLoading = false;
                                });
                              },
                            );
                          },
                        )
                      ],
                    ),
                    const SizedBox(height: 16,),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Icon(Icons.construction, color: Colors.white, size: 48,),
                        const SizedBox(width: 8,),
                        Text("白板打不开?", style: TextStyle(color: Colors.white, fontSize: 24),),
                        SizedBox(width: 16,),
                        FilledButton(
                          style: ButtonStyle(
                            foregroundColor: WidgetStateProperty.all(Colors.white),
                            backgroundColor: WidgetStateProperty.all(Colors.black),
                            side: WidgetStateProperty.all(
                              const BorderSide(color: Colors.white, width: 0.5),
                            ),
                            shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(Radius.circular(4)),
                              ),
                            ),
                            padding: WidgetStateProperty.all<EdgeInsetsGeometry>(const EdgeInsets.only(left: 6, right: 6)),
                          ),
                          onPressed: () async {
                            if (!pressed) {
                              setState(() {
                                isLoading = true;
                              });
                              await Future.delayed(const Duration(milliseconds: 500));
                              final result0 = await Process.run( 'wmic',
                                  ['process', 'where', "name='EasiRunner.exe'", 'call', 'terminate']
                              );
                              log(result0.stdout);
                              log(result0.stderr);

                              final result = await Process.run(
                                  'wmic',
                                  ['process', 'where', "ExecutablePath='${File("EasiNote.exe").absolute.path.replaceAll(r"\", r"\\")}'", 'get', 'ProcessId']
                              );

                              final lines = result.stdout.toString().split('\n');
                              int? id;
                              for (var line in lines) {
                                line = line.trim();
                                if (line.isNotEmpty && line != 'ProcessId') {
                                  id = int.tryParse(line) ?? -1;
                                }
                              }
                              if (id != null && id != -1) {
                                await killProcessByPid(id);
                                setState(() {
                                  pressed = true;
                                });
                              }
                            } else {
                              allExit(0);
                            }
                            manager.triggerFastSpin(this, (v) {
                              setState(() {
                                tempAngle.value = v;
                              });
                            });
                            setState(() {
                              isLoading = false;
                            });
                          },
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: Text(
                              pressed ? "点击重启" : "尝试结束后台进程",
                              key: ValueKey<bool>(pressed),
                            ),
                          )
                        ),
                      ],
                    ),
                    const SizedBox(height: 16,),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Icon(Icons.access_time, color: Colors.white, size: 48,),
                        const SizedBox(width: 8,),
                        Text("提示需要激活?", style: TextStyle(color: Colors.white, fontSize: 24),),
                        SizedBox(width: 16,),
                        FilledButton(
                          style: ButtonStyle(
                            foregroundColor: WidgetStateProperty.all(Colors.white),
                            backgroundColor: WidgetStateProperty.all(Colors.black),
                            side: WidgetStateProperty.all(
                              const BorderSide(color: Colors.white, width: 0.5),
                            ),
                            shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(Radius.circular(4)),
                              ),
                            ),
                            padding: WidgetStateProperty.all<EdgeInsetsGeometry>(const EdgeInsets.only(left: 6, right: 6)),
                          ),
                          onPressed: () async {
                            setState(() {
                              isLoading = true;
                            });
                            await Future.delayed(const Duration(milliseconds: 500));
                            final file = File(r"C:\ProgramData\EasiNote3\SWAF1501.swaf");
                            await Process.run( 'reg', ['delete', r'HKLM\SOFTWARE\WOW6432Node\EasiNote3', '/f'], runInShell: true,);
                            if (!pressedFix && await file.exists()) await file.delete();
                            manager.triggerFastSpin(this, (v) {
                              setState(() {
                                tempAngle.value = v;
                                pressedFix = true;
                              });
                            });
                            setState(() {
                              isLoading = false;
                            });},
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: !pressedFix ? Text(
                              "尝试修复",
                              key: ValueKey<bool>(pressedFix),
                            ) : Text("请定期启动此功能", key: ValueKey<bool>(pressedFix),),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16,),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.white, size: 48,),
                        const SizedBox(width: 8,),
                        Text("关于", style: TextStyle(color: Colors.white, fontSize: 24),),
                        SizedBox(width: 16,),
                        FilledButton(
                          style: ButtonStyle(
                            foregroundColor: WidgetStateProperty.all(Colors.white),
                            backgroundColor: WidgetStateProperty.all(Colors.black),
                            side: WidgetStateProperty.all(
                              const BorderSide(color: Colors.white, width: 0.5),
                            ),
                            shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(Radius.circular(4)),
                              ),
                            ),
                            padding: WidgetStateProperty.all<EdgeInsetsGeometry>(const EdgeInsets.only(left: 6, right: 6)),
                          ),
                          onPressed: () async {
                            launchUrlString("https://github.com/xXYxxdMC-GH");
                            },
                          child: Text("前往作者Github主页"),
                        ),
                      ],
                    ),
                  ],
                ),
                ),
              )
            ],
          ) : FutureBuilder<bool?>(
            future: isRunAsAdmin(),
            builder: (context, snapshot,) {
              final data = !(snapshot.data ?? false);
              return IgnorePointer(
                ignoring: data,
                child: Stack(
                  children: [
                    if (data) Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("请以管理员权限重启程序以注入",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 44,
                            ),
                          ),
                          const SizedBox(height: 16,),
                          ElevatedButton.icon(onPressed: () {
                            allExit(0);
                          }, label: Text("退出", style: const TextStyle(color: Colors.black),), icon: Icon(Icons.logout),
                            style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.all(Radius.circular(4)))
                            ),),
                        ],
                      ),
                    ),
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: data ? 10 : 0, sigmaY: data ? 10 : 0),
                      child: Stack(
                          children: [
                            Scaffold(
                              backgroundColor: Colors.transparent,
                              appBar: AppBar(
                                backgroundColor: Colors.transparent,
                                actions: [
                                  IconButton(onPressed: () {
                                    allExit(0);
                                  }, icon: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                  )),
                                  const SizedBox(width: 8,)
                                ],
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: ClipRect(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(padding: const EdgeInsets.only(left: 32), child:
                                    Text("EN3 Launcher 安装器",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 48,
                                      ),
                                    ),
                                    ),
                                    const SizedBox(height: 48,),
                                    Padding(padding: const EdgeInsets.only(left: 32), child:
                                    Text("希沃白板3路径:",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                      ),
                                    ),
                                    ),
                                    const SizedBox(height: 8,),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 32),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: Colors.black,
                                                border: Border.all(color: Colors.white, width: 1.5),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                                child: Align(
                                                  alignment: Alignment.centerLeft,
                                                  child: FutureBuilder<String?>(
                                                    future: findEasiNote(),
                                                    builder: (context, snapshot) {
                                                      final path = snapshot.data;
                                                      return Text(
                                                        path ?? "未找到",
                                                        style: const TextStyle(color: Colors.white, fontSize: 18),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          FilledButton(
                                            style: ButtonStyle(
                                              foregroundColor: WidgetStateProperty.all(Colors.white),
                                              backgroundColor: WidgetStateProperty.all(Colors.black),
                                              side: WidgetStateProperty.all(
                                                const BorderSide(color: Colors.white, width: 1.5),
                                              ),
                                              shape: WidgetStateProperty.all(
                                                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                              ),
                                            ),
                                            onPressed: () async {
                                              final path = await FilePickerWindows().getDirectoryPath();
                                              setState(() {
                                                rawPath = path;
                                              });
                                            },
                                            child: const Text("浏览..."),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 96),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Row(
                                        children: [
                                          const SizedBox(width: 20),
                                          Expanded(
                                            child: Text(
                                              "状态: $status",
                                              style: const TextStyle(color: Colors.white, fontSize: 24),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          FutureBuilder(future: findEasiNote(), builder: (_, snapshot) {
                                            return FilledButton(
                                                style: ButtonStyle(
                                                  foregroundColor: WidgetStateProperty.all(isLoading ? Colors.white30 : Colors.white),
                                                  backgroundColor: WidgetStateProperty.all(Colors.black),
                                                  side: WidgetStateProperty.all(
                                                    BorderSide(color: isLoading ? Colors.white30 : Colors.white, width: 1.5),
                                                  ),
                                                  shape: WidgetStateProperty.all(
                                                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                                  ),
                                                ),
                                                onPressed: isLoading ? null : () async {
                                                  setState(() {
                                                    isLoading = true;
                                                  });
                                                  String? currentPath = await findEasiNote();
                                                  if (injectDone) {
                                                    final targetPath = currentPath ?? rawPath;
                                                    if (targetPath != null) {
                                                      final file = File("$targetPath\\EasiNote3Launcher.exe");
                                                      if (await file.exists()) {
                                                        Process.start(
                                                            "$targetPath\\EasiNote3Launcher.exe",
                                                            [],
                                                            mode: ProcessStartMode.detached,
                                                            workingDirectory: targetPath
                                                        );
                                                        allExit(0);
                                                      } else {
                                                        setState(() => injectDone = false);
                                                      }
                                                    }
                                                  } else if (snapshot.data == null) {
                                                    final path = (await getApplicationCacheDirectory()).absolute.path;
                                                    await deleteDirectory(Directory(path));
                                                    final tasks = <Future<void>>[];
                                                    final map = {
                                                      "iZOJk3ibop2j": "5cy8",
                                                      "i7k3K3ibor8h": "a1g1",
                                                      "iPzth3ibolve": "4axz",
                                                      "igpgh3ibomyd": "a3h1"
                                                    };
                                                    for (int i = 0;i<4;i++) {
                                                      String? url = await fetchDownloadLink(map.keys.elementAt(i), map.values.elementAt(i));
                                                      if (url == null) continue;
                                                      tasks.add(downloadFile(url, index: i));
                                                    }
                                                    await Future.wait(tasks);
                                                    final chunks = [ "$path\\chunk_0.exe", "$path\\chunk_1.exe", "$path\\chunk_2.exe", "$path\\chunk_3.exe", ];
                                                    status = "正在合并文件...";
                                                    isRunning = true;
                                                    setState(() {});
                                                    await Future.delayed(const Duration(milliseconds: 250));
                                                    await mergeFiles(chunks, "$path\\EasiNoteSetup.exe");
                                                    status = "合并完成，开始安装，请按照指示安装";
                                                    setState(() {});
                                                    await Future.delayed(const Duration(milliseconds: 250));
                                                    if (await File("$path\\EasiNoteSetup.exe").exists()) {
                                                      await Process.start('$path\\EasiNoteSetup.exe', []);
                                                      status = "正在监视快捷方式的生成...";
                                                      setState(() {});
                                                      await monitorShortcut();
                                                      await Future.delayed(const Duration(milliseconds: 250));
                                                      await injectSelf((await findEasiNote())!);
                                                      status = "更新快捷方式中";
                                                      setState(() {});
                                                      await Future.delayed(const Duration(milliseconds: 250));
                                                      await updateUserShortcut((await findEasiNote())!);
                                                      status = "更新完成";
                                                      setState(() {});
                                                      await Future.delayed(const Duration(milliseconds: 250));
                                                      setState(() {
                                                        injectDone = true;
                                                      });
                                                    }
                                                  } else {
                                                    setState(() {
                                                      isRunning = true;
                                                    });
                                                    await injectSelf(snapshot.data!);
                                                    await Future.delayed(const Duration(milliseconds: 250));
                                                    status = "更新快捷方式中";
                                                    setState(() {});
                                                    await Future.delayed(const Duration(milliseconds: 250));
                                                    await updateUserShortcut((await findEasiNote())!);
                                                    status = "更新完成";
                                                    setState(() {});
                                                    await Future.delayed(const Duration(milliseconds: 250));
                                                    setState(() {
                                                      injectDone = true;
                                                    });
                                                  }
                                                  setState(() {
                                                    isLoading = false;
                                                    isRunning = false;
                                                  });
                                                },
                                                child: Row(
                                                  children: [
                                                    Icon(snapshot.data == null ? Icons.download : injectDone ? Icons.check : Icons.play_arrow),
                                                    const SizedBox(width: 8,),
                                                    Text(snapshot.data == null ? "下载希沃3安装包" : injectDone ? "启动希沃白板3" : "启动任务")
                                                  ],
                                                )
                                            );
                                          })
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 200),
                                        child: isRunning ? LinearProgressIndicator(
                                          color: Colors.white,
                                          backgroundColor: Colors.white30,) : Row(
                                          children: [
                                            Flexible(
                                              flex: 1,
                                              child: TweenAnimationBuilder<double>(
                                                tween: Tween<double>(begin: 0, end: progress / 100),
                                                curve: Curves.fastOutSlowIn,
                                                duration: const Duration(milliseconds: 300),
                                                builder: (context, value, child) {
                                                  return LinearProgressIndicator(
                                                    value: value,
                                                    color: Colors.white,
                                                    backgroundColor: Colors.white30,
                                                  );
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 1),
                                            Flexible(
                                              flex: 1,
                                              child: TweenAnimationBuilder<double>(
                                                tween: Tween<double>(begin: 0, end: progress1 / 100),
                                                curve: Curves.fastOutSlowIn,
                                                duration: const Duration(milliseconds: 300),
                                                builder: (context, value, child) {
                                                  return LinearProgressIndicator(
                                                    value: value,
                                                    color: Colors.white,
                                                    backgroundColor: Colors.white30,
                                                  );
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 1),
                                            Flexible(
                                              flex: 1,
                                              child: TweenAnimationBuilder<double>(
                                                tween: Tween<double>(begin: 0, end: progress2 / 100),
                                                curve: Curves.fastOutSlowIn,
                                                duration: const Duration(milliseconds: 300),
                                                builder: (context, value, child) {
                                                  return LinearProgressIndicator(
                                                    value: value,
                                                    color: Colors.white,
                                                    backgroundColor: Colors.white30,
                                                  );
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 1),
                                            Flexible(
                                              flex: 1,
                                              child: TweenAnimationBuilder<double>(
                                                tween: Tween<double>(begin: 0, end: progress3 / 100),
                                                curve: Curves.fastOutSlowIn,
                                                duration: const Duration(milliseconds: 300),
                                                builder: (context, value, child) {
                                                  return LinearProgressIndicator(
                                                    value: value,
                                                    color: Colors.white,
                                                    backgroundColor: Colors.white30,
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        )
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                    )
                  ],
                )
              );
            },
          )
        )
      )
    );
  }
}

Future<void> deleteDirectory(Directory dir) async {
  if (!await dir.exists()) return;

  await for (var entity in dir.list(recursive: false)) {
    if (entity is File) {
      await entity.delete();
    } else if (entity is Directory) {
      await deleteDirectory(entity);
    } else if (entity is Link) {
      await entity.delete();
    }
  }

  await dir.delete();
}

Future<void> monitorShortcut({
  Duration interval = const Duration(seconds: 5),
}) async {
  while (true) {
    final file = File("C:\\Users\\Public\\Desktop\\希沃白板 3.lnk");
    if (await file.exists()) {
      break;
    } else {
      await Future.delayed(interval);
    }
  }
}

Future<void> updateUserShortcut(String path) async {
  final script = '''
  \$shortcutPath = "C:\\Users\\Public\\Desktop\\希沃白板 3.lnk"
  if (Test-Path \$shortcutPath) {
      Remove-Item \$shortcutPath -Force
  }
  \$target = "$path\\\\EasiNote3Launcher.exe"
  if (Test-Path \$target) {
      \$WshShell = New-Object -ComObject WScript.Shell
      \$Shortcut = \$WshShell.CreateShortcut(\$shortcutPath)
      \$Shortcut.TargetPath = \$target
      \$Shortcut.WorkingDirectory = "$path"
      \$Shortcut.IconLocation = "\$target,0"
      \$Shortcut.Save()
  } else {
      Write-Output "目标程序不存在: \$target"
  }
  ''';

  await Process.run("powershell", ["-Command", script]);
}

Future<Map<String, dynamic>> fetchPageInfo(String shareId) async {
  final dio = Dio();
  final shareUrl = "https://wwbug.lanzouu.com/$shareId";
  final response = await dio.get(shareUrl);

  if (response.statusCode == 200) {
    final html = response.data.toString();

    final regSign = RegExp(r"'sign':'([A-Za-z0-9_]+)'");
    final signs = regSign.allMatches(html).map((m) => m.group(1)!).toList();

    final regUrl = RegExp(r"url\s*:\s*'([^']+ajaxm\.php\?file=\d+)'");
    final matchUrl = regUrl.firstMatch(html);
    final ajaxUrl = matchUrl?.group(1);

    return {
      "signs": signs,
      "ajaxUrl": ajaxUrl,
    };
  }
  return {"signs": [], "ajaxUrl": null};
}

Future<String?> fetchDownloadLink(String shareId, String password) async {
  final pageInfo = await fetchPageInfo(shareId);
  final signs = pageInfo["signs"] as List<String>;
  final ajaxUrl = pageInfo["ajaxUrl"] as String?;

  if (ajaxUrl == null || signs.isEmpty) {
    return null;
  }

  final dio = Dio();

  for (final sign in signs.reversed) {
    final data = {
      "action": "downprocess",
      "sign": sign,
      "kd": "1",
      "p": password,
    };

    final Response response;

    try {
      response = await dio.post(
        "https://wwbug.lanzouu.com$ajaxUrl",
        data: FormData.fromMap(data),
        options: Options(
          headers: {
            "accept": "application/json, text/javascript, */*",
            "accept-encoding": "gzip, deflate, br, zstd",
            "accept-language": "zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6,pt-BR;q=0.5,pt;q=0.4,ja;q=0.3",
            "cache-control": "no-cache",
            "content-type": "application/x-www-form-urlencoded",
            "origin": "https://wwbug.lanzouu.com",
            "pragma": "no-cache",
            "referer": "https://wwbug.lanzouu.com/$shareId",
            "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36 Edg/144.0.0.0",
            "x-requested-with": "XMLHttpRequest",
          },
        ),
      );
    } catch (e) {
      continue;
    }

    if (response.statusCode == 200) {
      final json = response.data;
      if (json["zt"] == 1) {
        return "${json["dom"]}/file/${json["url"]}";
      }
    }
  }

  return null;
}

Future<void> mergeFiles(List<String> chunks, String outputPath) async {
  final outFile = File(outputPath).openWrite();

  for (final chunk in chunks) {
    final file = File(chunk);
    final bytes = await file.readAsBytes();
    outFile.add(bytes);
  }

  await outFile.flush();
  await outFile.close();
}

Future<void> killProcessByPid(int pid) async {
  final result = await Process.run( 'wmic',
      ['process', 'where', 'ProcessId=$pid', 'call', 'terminate']
  );
  log(result.stdout);
  log(result.stderr);
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

void allExit(int code) async {
  if (file != null) await file?.close();
  exit(code);
}

Future<void> runAsAdmin() async {
  final exePath = Platform.resolvedExecutable;
  await Process.run('powershell', [
    'Start-Process',
    exePath,
    '-Verb',
    'RunAs'
  ]);
}

Future<bool> isRunAsAdmin() async {
  final result = await Process.run('net', ['session']);
  return result.exitCode == 0;
}

Future<void> clearLogFile() async {
  if (await logFile.exists()) {
    await logFile.writeAsString('', mode: FileMode.write);
  } else {
    await logFile.create(recursive: true);
  }
}

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

Future<bool> isProcessRunning() async {
  final result = await Process.run('wmic', [
    "process", "where", "name='EasiNote.exe'"
  ]);
  if (result.exitCode != 0) {
    return false;
  }
  final output = result.stdout.toString();
  return output.contains(File("EasiNote.exe").absolute.path);
}

Future<String> extractCdb() async {
  final bytes = await rootBundle.load('assets/Y2RiLmV4ZQ==');
  final tempDir = Directory.systemTemp.path;
  final exePath = path.join(tempDir, 'cdb.exe');
  final file = File(exePath);
  await file.writeAsBytes(bytes.buffer.asUint8List());
  return exePath;
}

Future<void> extractTtf() async {
  final bytes = await rootBundle.load('assets/bWluZWNyYWZ0LnR0Zg==');
  final fontLoader = FontLoader("Minecraft")
    ..addFont(Future.value(bytes));
  await fontLoader.load();
}

final Map<String, String> assetHashes = {
  'assets/eHh5eHhkbWMucG5n': '44edd63d2d5118cc1a7cdc45c360cd50315a034106304ad5f893980a92d5ba91',
  'assets/d2VsY29tZV9iYWNrZ3JvdW5kLnBuZw==': 'f7bc9b3f03a1b8ea6cd40d1b4c47eb048a95e76415df27d96ab9cbd77ee323b1',
  'assets/Y2RiLmV4ZQ==': 'd84075c96f934f67ffd419e2ed3d3b545692bffcc59192dbe8d5c064e9bf01bc',
  'assets/bWluZWNyYWZ0LnR0Zg==': 'ab2f01dc5deac4cdec519fe2d6ac92398fe998737faea5bd59c93c5e539271aa',
};

Future<void> verifyAssets() async {
  for (final entry in assetHashes.entries) {
    final assetPath = entry.key;
    final expectedHash = entry.value;

    final bytes = await rootBundle.load(assetPath);
    final data = bytes.buffer.asUint8List();

    final hash = sha256.convert(data).toString();

    if (hash != expectedHash) {
      throw VerifyAssetsException(assetPath);
    }
  }
}

String randomString(int length) {
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rand = Random();
  return List.generate(length, (i) => chars[rand.nextInt(chars.length)]).join();
}

Future<RandomAccessFile?> startLock() async {
  final lockFile = File('app.lock');
  final raf = await lockFile.open(mode: FileMode.write);
  try {
    await raf.lock();
    _startRefresh(lockFile);
    return raf;
  } catch (e) {
    allExit(0);
  }
  return null;
}

void _startRefresh(File lockFile) {
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    if (!await lockFile.exists()) {
      await lockFile.writeAsString('');
    }
  });
}

Future<void> recordLaunchAndCheckSettingMode() async {
  final file = File('launch.log');
  final now = DateTime.now().millisecondsSinceEpoch;

  await file.writeAsString('$now,$processId\n', mode: FileMode.append);

  final lines = await file.readAsLines();

  final recent = lines.where((line) {
    final parts = line.split(',');
    if (parts.isEmpty) return false;
    final ts = int.tryParse(parts.first) ?? 0;
    return now - ts <= 10000;
  }).toList();

  if (recent.length >= 8) {
    settingMode = true;
    await file.writeAsString("", mode: FileMode.write);
  }
}

class VerifyAssetsException implements Exception {
  final String path;

  const VerifyAssetsException(this.path);

  @override
  String toString() {
    return "Assets Verity Failed, because of $path incorrect";
  }
}

class RotationManager extends ChangeNotifier {
  late AnimationController baseController;
  late Animation<double> baseRotation;

  RotationManager(TickerProvider vsync) {
    baseController = AnimationController(
      vsync: vsync,
      duration: const Duration(seconds: 12),
    )..repeat();

    baseRotation = Tween<double>(begin: 0, end: 1).animate(baseController);
  }

  Future<void> triggerFastSpin(TickerProvider vsync, void Function(double) onAngle) async {
    final tempController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 600),
    );

    final tempRotation = Tween<double>(begin: 0, end: -1 * 3.1415926).animate(
      CurvedAnimation(parent: tempController, curve: Curves.fastOutSlowIn),
    );

    tempController.addListener(() {
      onAngle(tempRotation.value);
    });

    baseController.stop();

    await tempController.forward();
    tempController.dispose();

    baseController.repeat();
  }

  void disposeManager() {
    baseController.dispose();
  }
}