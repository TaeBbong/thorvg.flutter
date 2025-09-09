import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:thorvg/src/thorvg.dart' as module;
import 'package:thorvg/src/utils.dart';

class Lottie extends StatefulWidget {
  final Future<String> data;
  final double? width;
  final double? height;

  final bool animate;
  final bool repeat;
  final bool reverse;

  final void Function(module.Thorvg)? onLoaded;

  const Lottie({
    Key? key,
    required this.data,
    required this.width,
    required this.height,
    required this.animate,
    required this.repeat,
    required this.reverse,
    this.onLoaded,
  }) : super(key: key);

  static Lottie asset(
    String name, {
    Key? key,
    double? width,
    double? height,
    bool? animate,
    bool? repeat,
    bool? reverse,
    AssetBundle? bundle,
    String? package,
    void Function(module.Thorvg)? onLoaded,
  }) {
    return Lottie(
      key: key,
      data: parseAsset(name, bundle, package),
      width: width,
      height: height,
      animate: animate ?? true,
      repeat: repeat ?? true,
      reverse: reverse ?? false,
      onLoaded: onLoaded,
    );
  }

  static Lottie file(
    io.File file, {
    Key? key,
    double? width,
    double? height,
    bool? animate,
    bool? repeat,
    bool? reverse,
    void Function(module.Thorvg)? onLoaded,
  }) {
    return Lottie(
      key: key,
      data: parseFile(file),
      width: width,
      height: height,
      animate: animate ?? true,
      repeat: repeat ?? true,
      reverse: reverse ?? false,
      onLoaded: onLoaded,
    );
  }

  static Lottie memory(
    Uint8List bytes, {
    Key? key,
    double? width,
    double? height,
    bool? animate,
    bool? repeat,
    bool? reverse,
    void Function(module.Thorvg)? onLoaded,
  }) {
    return Lottie(
      key: key,
      data: parseMemory(bytes),
      width: width,
      height: height,
      animate: animate ?? true,
      repeat: repeat ?? true,
      reverse: reverse ?? false,
      onLoaded: onLoaded,
    );
  }

  static Lottie network(String src,
      {Key? key,
      double? width,
      double? height,
      bool? animate,
      bool? repeat,
      bool? reverse,
      void Function(module.Thorvg)? onLoaded}) {
    return Lottie(
        key: key,
        data: parseSrc(src),
        width: width,
        height: height,
        animate: animate ?? true,
        repeat: repeat ?? true,
        reverse: reverse ?? false,
        onLoaded: onLoaded);
  }

  @override
  State createState() => _State();
}

class _State extends State<Lottie> {
  module.Thorvg? tvg;
  ui.Image? img;
  int? _frameCallbackId;

  String data = "";
  String errorMsg = "";

  // Canvas size
  double width = 0;
  double height = 0;

  // Canvas size applied with constraints
  double canvasWidth = 0;
  double canvasHeight = 0;

  // Original size (lottie)
  int lottieWidth = 0;
  int lottieHeight = 0;

  // dpr
  double dpr = 1.0;

  // Render size (calculated)
  double get renderWidth => (canvasWidth == 0)
      ? (lottieWidth > width ? width : lottieWidth).toDouble() * dpr
      : canvasWidth * dpr;
  double get renderHeight => (canvasHeight == 0)
      ? (lottieHeight > height ? height : lottieHeight).toDouble() * dpr
      : canvasHeight * dpr;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void reassemble() {
    super.reassemble();

    if (tvg == null) {
      setState(() {
        errorMsg = "Thorvg module has not been initialized";
      });
      return;
    }

    setState(() {
      errorMsg = "";
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _unscheduleTick();

      _loadData();
      _updateLottieSize();
      _updateCanvasSize();
      _tvgLoad();

      _scheduleTick();
    });
  }

  @override
  void dispose() {
    super.dispose();

    _unscheduleTick();
    tvg!.delete();
  }

  void _updateLottieSize() {
    final info = jsonDecode(data);

    setState(() {
      lottieWidth = info['w'] ?? widget.width;
      lottieHeight = info['h'] ?? widget.height;
    });
  }

  void _updateCanvasSize() {
    setState(() {
      width = widget.width ?? lottieWidth.toDouble();
      height = widget.height ?? lottieHeight.toDouble();
    });
  }

  /* TVG function wrapper
    * Has `_tvg` prefix
    * Should check error and update error message
  */
  void _tvgLoad() {
    try {
      tvg!.load(data, renderWidth.toInt(), renderHeight.toInt(), widget.animate,
          widget.repeat, widget.reverse);
    } catch (err) {
      setState(() {
        errorMsg = err.toString();
      });
    }
  }

  void _tvgResize() {
    tvg!.resize(renderWidth.toInt(), renderHeight.toInt());
  }

  Uint8List? _tvgAnimLoop() {
    try {
      return tvg!.animLoop();
    } catch (err) {
      setState(() {
        errorMsg = err.toString();
      });
    }
    return null;
  }

  Future _loadData() async {
    try {
      data = await widget.data;
    } catch (err) {
      setState(() {
        errorMsg = err.toString();
      });
    }
  }

  void _scheduleTick() {
    _frameCallbackId = SchedulerBinding.instance.scheduleFrameCallback(_tick);
  }

  void _unscheduleTick() {
    if (_frameCallbackId == null) {
      return;
    }

    SchedulerBinding.instance.cancelFrameCallbackWithId(_frameCallbackId!);
    _frameCallbackId = null;
  }

  void _tick(Duration timestamp) async {
    _scheduleTick();

    final buffer = _tvgAnimLoop();
    if (buffer == null) {
      return;
    }

    final image =
        await decodeImage(buffer, renderWidth.toInt(), renderHeight.toInt());
    setState(() {
      img = image;
    });
  }

  void _load() async {
    await _loadData();
    if (data.isEmpty) return;

    _updateLottieSize();
    _updateCanvasSize();

    tvg ??= module.Thorvg();
    _tvgLoad();

    if (widget.onLoaded != null) {
      widget.onLoaded!(tvg!);
    }

    _scheduleTick();
  }

  Size _computeCanvasSize(BoxConstraints constraints, int lw, int lh) {
    if (lw > 0 && lh > 0) {
      return constraints.constrainSizeAndAttemptToPreserveAspectRatio(
        Size(lw.toDouble(), lh.toDouble()),
      );
    }

    final double w = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : (constraints.minWidth > 0 ? constraints.minWidth : 0);
    final double h = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : (constraints.minHeight > 0 ? constraints.minHeight : 0);

    return Size(w, h);
  }

  @override
  Widget build(BuildContext context) {
    if (errorMsg.isNotEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: ErrorWidget(errorMsg),
      );
    }

    if (img == null) {
      return Container();
    }

    // Apply DPR to balance rendering quality and performance
    final deviceDpr = 1 + (MediaQuery.of(context).devicePixelRatio - 1) * 0.75;
    if (dpr != deviceDpr) {
      dpr = deviceDpr;
      _tvgResize();
    }

    return LayoutBuilder(builder: (context, constraints) {
      final BoxConstraints prefConstraints =
          BoxConstraints.tightFor(width: width, height: height)
              .enforce(constraints);

      final Size canvasSize =
          _computeCanvasSize(prefConstraints, lottieWidth, lottieHeight);

      if (canvasWidth != canvasSize.width ||
          canvasHeight != canvasSize.height) {
        canvasWidth = canvasSize.width;
        canvasHeight = canvasSize.height;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _tvgResize();
        });
      }

      return Container(
        width: canvasWidth,
        height: canvasHeight,
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(color: Colors.transparent),
        child: Transform.scale(
          scale: 1.0 / dpr,
          child: CustomPaint(
            painter: TVGCanvas(
                width: canvasWidth,
                height: canvasHeight,
                lottieWidth: lottieWidth.toDouble(),
                lottieHeight: lottieHeight.toDouble(),
                renderWidth: renderWidth,
                renderHeight: renderHeight,
                image: img!),
          ),
        ),
      );
    });
  }
}

class TVGCanvas extends CustomPainter {
  TVGCanvas(
      {required this.image,
      required this.width,
      required this.height,
      required this.lottieWidth,
      required this.lottieHeight,
      required this.renderWidth,
      required this.renderHeight});

  double width;
  double height;

  double lottieWidth;
  double lottieHeight;

  double renderWidth;
  double renderHeight;

  ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final left = (width - renderWidth) / 2;
    final top = (height - renderHeight) / 2;

    paintImage(
      canvas: canvas,
      rect: Rect.fromLTWH(left, top, renderWidth, renderHeight),
      image: image,
      fit: BoxFit.none, //NOTE: Should make it a param
      filterQuality: FilterQuality.high, //NOTE: Should make it a param
      alignment: Alignment.center, //NOTE: Should make it a param
    );
  }

  @override
  bool shouldRepaint(TVGCanvas oldDelegate) {
    return image != oldDelegate.image;
  }
}
