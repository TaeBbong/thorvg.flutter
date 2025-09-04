import 'package:flutter/widgets.dart';
import 'dart:ui' as ui;

class LottieBox extends LeafRenderObjectWidget {
  const LottieBox({
    super.key,
    required this.image,
    required this.intrinsicSize, // Lottie 원본 크기 (w,h) or null
    this.preferredWidth, // 위젯에서 지정한 width (없으면 null)
    this.preferredHeight, // 위젯에서 지정한 height (없으면 null)
    this.fit = BoxFit.none, // 기존 동작 유지
    this.alignment = Alignment.center,
    this.onNeedRaster, // 레이아웃 결과에 맞춰 래스터 크기 요청 콜백(논리 px)
    this.devicePixelRatio = 1.0,
  });

  final ui.Image? image;
  final Size? intrinsicSize;
  final double? preferredWidth;
  final double? preferredHeight;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final ValueChanged<Size>? onNeedRaster;
  final double devicePixelRatio;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderLottieBox(
      image: image,
      intrinsicSize: intrinsicSize,
      preferredWidth: preferredWidth,
      preferredHeight: preferredHeight,
      fit: fit,
      alignment: alignment,
      onNeedRaster: onNeedRaster,
      devicePixelRatio: devicePixelRatio,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderLottieBox renderObject) {
    renderObject
      ..image = image
      ..intrinsicSize = intrinsicSize
      ..preferredWidth = preferredWidth
      ..preferredHeight = preferredHeight
      ..fit = fit
      ..alignment = alignment
      ..onNeedRaster = onNeedRaster
      ..devicePixelRatio = devicePixelRatio;
  }
}

class RenderLottieBox extends RenderBox {
  RenderLottieBox({
    ui.Image? image,
    Size? intrinsicSize,
    double? preferredWidth,
    double? preferredHeight,
    BoxFit fit = BoxFit.none,
    AlignmentGeometry alignment = Alignment.center,
    ValueChanged<Size>? onNeedRaster,
    double devicePixelRatio = 1.0,
  })  : _image = image,
        _intrinsicSize = intrinsicSize,
        _preferredWidth = preferredWidth,
        _preferredHeight = preferredHeight,
        _fit = fit,
        _alignment = alignment,
        _onNeedRaster = onNeedRaster,
        _devicePixelRatio = devicePixelRatio;

  ui.Image? _image;
  Size? _intrinsicSize;
  double? _preferredWidth;
  double? _preferredHeight;
  BoxFit _fit;
  AlignmentGeometry _alignment;
  ValueChanged<Size>? _onNeedRaster;
  double _devicePixelRatio;

  // 마지막으로 요청한 래스터 타깃(논리 px), 불필요한 반복 요청 방지용
  Size? _lastRasterLogicalSize;

  // ===== setters =====
  set image(ui.Image? v) {
    if (identical(v, _image)) return;
    _image = v;
    markNeedsPaint();
  }

  set intrinsicSize(Size? v) {
    if (v == _intrinsicSize) return;
    _intrinsicSize = v;
    markNeedsLayout();
  }

  set preferredWidth(double? v) {
    if (v == _preferredWidth) return;
    _preferredWidth = v;
    markNeedsLayout();
  }

  set preferredHeight(double? v) {
    if (v == _preferredHeight) return;
    _preferredHeight = v;
    markNeedsLayout();
  }

  set fit(BoxFit v) {
    if (v == _fit) return;
    _fit = v;
    markNeedsLayout(); // paint만으로도 되지만, 목적 사이즈가 달라질 수 있음
  }

  set alignment(AlignmentGeometry v) {
    if (v == _alignment) return;
    _alignment = v;
    markNeedsPaint();
  }

  set onNeedRaster(ValueChanged<Size>? v) {
    _onNeedRaster = v;
  }

  set devicePixelRatio(double v) {
    if (v == _devicePixelRatio) return;
    _devicePixelRatio = v;
    // 보통 DPR 바뀌면 래스터 타깃을 재요청하는 편이 좋다
    markNeedsLayout();
  }

  // ====== 핵심: constraints → size 결정 ======
  Size _sizeForConstraints(BoxConstraints constraints) {
    // 1) 위젯이 선호 크기(width/height)를 일부 제공했다면 constraints에 “접어 넣기”
    constraints = BoxConstraints.tightFor(
      width: _preferredWidth,
      height: _preferredHeight,
    ).enforce(constraints);

    // 2) Lottie 원본 크기 없으면 최소값 반환(= 일반적인 패턴)
    if (_intrinsicSize == null) {
      return constraints.smallest;
    }

    // 3) 원본 종횡비 보존하며 constraints 안에서 최대화
    return constraints
        .constrainSizeAndAttemptToPreserveAspectRatio(_intrinsicSize!);
  }

  // ====== Intrinsics ======
  @override
  double computeMinIntrinsicWidth(double height) {
    if (_preferredWidth == null &&
        _preferredHeight == null &&
        _intrinsicSize == null) {
      return 0.0;
    }
    return _sizeForConstraints(BoxConstraints.tightForFinite(height: height))
        .width;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    return _sizeForConstraints(BoxConstraints.tightForFinite(height: height))
        .width;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    if (_preferredWidth == null &&
        _preferredHeight == null &&
        _intrinsicSize == null) {
      return 0.0;
    }
    return _sizeForConstraints(BoxConstraints.tightForFinite(width: width))
        .height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return _sizeForConstraints(BoxConstraints.tightForFinite(width: width))
        .height;
  }

  @override
  bool hitTestSelf(Offset position) => true;

  // dry layout (Sliver 등 사전 계산 경로)
  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return _sizeForConstraints(constraints);
  }

  // 실제 레이아웃
  @override
  void performLayout() {
    size = _sizeForConstraints(constraints);

    // ---- 래스터 타깃 사이즈(논리 px) 산출 & 요청 ----
    // 목적지 사각형은 전체 박스(size), fit에 따라 이미지가 차지할 실제 논리 크기를 구함
    final contentSize = _intrinsicSize ?? Size.zero;
    Size destLogical;

    if (contentSize.isEmpty) {
      destLogical = size;
    } else {
      final fitted = applyBoxFit(_fit, contentSize, size);
      destLogical = fitted.destination;
    }

    // 너무 자주 호출되지 않도록 기존과 달라졌을 때만
    if (_onNeedRaster != null) {
      final prev = _lastRasterLogicalSize;
      final changed = prev == null ||
          (prev.width - destLogical.width).abs() >= 1.0 ||
          (prev.height - destLogical.height).abs() >= 1.0;
      if (changed) {
        _lastRasterLogicalSize = destLogical;
        _onNeedRaster!.call(destLogical);
      }
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final img = _image;
    if (img == null) return;

    // paintImage는 내부에서 fit/alignment를 적용해준다.
    paintImage(
      canvas: context.canvas,
      rect: offset & size,
      image: img,
      fit: _fit,
      alignment: _alignment.resolve(TextDirection.ltr),
      filterQuality: FilterQuality.high,
    );
  }
}
