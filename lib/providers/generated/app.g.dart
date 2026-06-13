// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../app.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RealTunEnable)
const realTunEnableProvider = RealTunEnableProvider._();

final class RealTunEnableProvider
    extends $NotifierProvider<RealTunEnable, bool> {
  const RealTunEnableProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'realTunEnableProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$realTunEnableHash();

  @$internal
  @override
  RealTunEnable create() => RealTunEnable();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$realTunEnableHash() => r'a4e995c86deca4c8307966470e69d93d64a40df6';

abstract class _$RealTunEnable extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(Logs)
const logsProvider = LogsProvider._();

final class LogsProvider extends $NotifierProvider<Logs, FixedList<Log>> {
  const LogsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'logsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$logsHash();

  @$internal
  @override
  Logs create() => Logs();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FixedList<Log> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FixedList<Log>>(value),
    );
  }
}

String _$logsHash() => r'56fb8aa9d62a97b026b749d204576a7384084737';

abstract class _$Logs extends $Notifier<FixedList<Log>> {
  FixedList<Log> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<FixedList<Log>, FixedList<Log>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FixedList<Log>, FixedList<Log>>,
              FixedList<Log>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(Requests)
const requestsProvider = RequestsProvider._();

final class RequestsProvider
    extends $NotifierProvider<Requests, FixedList<Connection>> {
  const RequestsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'requestsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$requestsHash();

  @$internal
  @override
  Requests create() => Requests();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FixedList<Connection> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FixedList<Connection>>(value),
    );
  }
}

String _$requestsHash() => r'51c9dbba18649206b22dd0ba86c58ab986fc0939';

abstract class _$Requests extends $Notifier<FixedList<Connection>> {
  FixedList<Connection> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<FixedList<Connection>, FixedList<Connection>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FixedList<Connection>, FixedList<Connection>>,
              FixedList<Connection>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(Providers)
const providersProvider = ProvidersProvider._();

final class ProvidersProvider
    extends $NotifierProvider<Providers, List<ExternalProvider>> {
  const ProvidersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'providersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$providersHash();

  @$internal
  @override
  Providers create() => Providers();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<ExternalProvider> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<ExternalProvider>>(value),
    );
  }
}

String _$providersHash() => r'69e480ef409837596937d233e45b9995a83b3949';

abstract class _$Providers extends $Notifier<List<ExternalProvider>> {
  List<ExternalProvider> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<List<ExternalProvider>, List<ExternalProvider>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<ExternalProvider>, List<ExternalProvider>>,
              List<ExternalProvider>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(Packages)
const packagesProvider = PackagesProvider._();

final class PackagesProvider
    extends $NotifierProvider<Packages, List<Package>> {
  const PackagesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'packagesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$packagesHash();

  @$internal
  @override
  Packages create() => Packages();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Package> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Package>>(value),
    );
  }
}

String _$packagesHash() => r'84bff9f5271622ed4199ecafacda8e74fa444fe2';

abstract class _$Packages extends $Notifier<List<Package>> {
  List<Package> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<List<Package>, List<Package>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<Package>, List<Package>>,
              List<Package>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(AppBrightness)
const appBrightnessProvider = AppBrightnessProvider._();

final class AppBrightnessProvider
    extends $NotifierProvider<AppBrightness, Brightness?> {
  const AppBrightnessProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appBrightnessProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appBrightnessHash();

  @$internal
  @override
  AppBrightness create() => AppBrightness();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Brightness? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Brightness?>(value),
    );
  }
}

String _$appBrightnessHash() => r'bc893bacdc2645c985037d3754bad4e651587771';

abstract class _$AppBrightness extends $Notifier<Brightness?> {
  Brightness? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<Brightness?, Brightness?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Brightness?, Brightness?>,
              Brightness?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(Traffics)
const trafficsProvider = TrafficsProvider._();

final class TrafficsProvider
    extends $NotifierProvider<Traffics, FixedList<Traffic>> {
  const TrafficsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trafficsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trafficsHash();

  @$internal
  @override
  Traffics create() => Traffics();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FixedList<Traffic> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FixedList<Traffic>>(value),
    );
  }
}

String _$trafficsHash() => r'c3f33e9be5ae399562a380156280406fdeeb72aa';

abstract class _$Traffics extends $Notifier<FixedList<Traffic>> {
  FixedList<Traffic> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<FixedList<Traffic>, FixedList<Traffic>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FixedList<Traffic>, FixedList<Traffic>>,
              FixedList<Traffic>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(TotalTraffic)
const totalTrafficProvider = TotalTrafficProvider._();

final class TotalTrafficProvider
    extends $NotifierProvider<TotalTraffic, Traffic> {
  const TotalTrafficProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'totalTrafficProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$totalTrafficHash();

  @$internal
  @override
  TotalTraffic create() => TotalTraffic();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Traffic value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Traffic>(value),
    );
  }
}

String _$totalTrafficHash() => r'cc993ec58fa4c8ee0dbbf2e8a146f7039e818d7e';

abstract class _$TotalTraffic extends $Notifier<Traffic> {
  Traffic build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<Traffic, Traffic>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Traffic, Traffic>,
              Traffic,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(LocalIp)
const localIpProvider = LocalIpProvider._();

final class LocalIpProvider extends $NotifierProvider<LocalIp, String?> {
  const LocalIpProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localIpProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localIpHash();

  @$internal
  @override
  LocalIp create() => LocalIp();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$localIpHash() => r'2dd4afdb29db4791ebd80d976f9ea31c62959199';

abstract class _$LocalIp extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(RunTime)
const runTimeProvider = RunTimeProvider._();

final class RunTimeProvider extends $NotifierProvider<RunTime, int?> {
  const RunTimeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'runTimeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$runTimeHash();

  @$internal
  @override
  RunTime create() => RunTime();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }
}

String _$runTimeHash() => r'9aab44f2234590a70cbf0ff7394e496c2c97c00e';

abstract class _$RunTime extends $Notifier<int?> {
  int? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<int?, int?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int?, int?>,
              int?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(ViewSize)
const viewSizeProvider = ViewSizeProvider._();

final class ViewSizeProvider extends $NotifierProvider<ViewSize, Size> {
  const ViewSizeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'viewSizeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$viewSizeHash();

  @$internal
  @override
  ViewSize create() => ViewSize();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Size value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Size>(value),
    );
  }
}

String _$viewSizeHash() => r'07f9cce28a69d1496ba4643ef72a739312f6fc28';

abstract class _$ViewSize extends $Notifier<Size> {
  Size build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<Size, Size>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Size, Size>,
              Size,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(viewWidth)
const viewWidthProvider = ViewWidthProvider._();

final class ViewWidthProvider
    extends $FunctionalProvider<double, double, double>
    with $Provider<double> {
  const ViewWidthProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'viewWidthProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$viewWidthHash();

  @$internal
  @override
  $ProviderElement<double> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  double create(Ref ref) {
    return viewWidth(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double>(value),
    );
  }
}

String _$viewWidthHash() => r'a469c3414170a6616ff3264962e7f160b2edceca';

@ProviderFor(viewMode)
const viewModeProvider = ViewModeProvider._();

final class ViewModeProvider
    extends $FunctionalProvider<ViewMode, ViewMode, ViewMode>
    with $Provider<ViewMode> {
  const ViewModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'viewModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$viewModeHash();

  @$internal
  @override
  $ProviderElement<ViewMode> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ViewMode create(Ref ref) {
    return viewMode(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ViewMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ViewMode>(value),
    );
  }
}

String _$viewModeHash() => r'736e2acc7e7d98ee30132de1990bf85f9506b47a';

@ProviderFor(isMobileView)
const isMobileViewProvider = IsMobileViewProvider._();

final class IsMobileViewProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  const IsMobileViewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isMobileViewProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isMobileViewHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isMobileView(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isMobileViewHash() => r'554c9ed269a02af001e623e596622e2bb2d658e7';

@ProviderFor(viewHeight)
const viewHeightProvider = ViewHeightProvider._();

final class ViewHeightProvider
    extends $FunctionalProvider<double, double, double>
    with $Provider<double> {
  const ViewHeightProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'viewHeightProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$viewHeightHash();

  @$internal
  @override
  $ProviderElement<double> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  double create(Ref ref) {
    return viewHeight(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double>(value),
    );
  }
}

String _$viewHeightHash() => r'410aee5b41388226ab16737f0e85a56f7e9fe801';

@ProviderFor(Init)
const initProvider = InitProvider._();

final class InitProvider extends $NotifierProvider<Init, bool> {
  const InitProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'initProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$initHash();

  @$internal
  @override
  Init create() => Init();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$initHash() => r'7d3f11c8aff7a1924c5ec8886b2cd2cbdda57c3f';

abstract class _$Init extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(CurrentPageLabel)
const currentPageLabelProvider = CurrentPageLabelProvider._();

final class CurrentPageLabelProvider
    extends $NotifierProvider<CurrentPageLabel, PageLabel> {
  const CurrentPageLabelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentPageLabelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentPageLabelHash();

  @$internal
  @override
  CurrentPageLabel create() => CurrentPageLabel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PageLabel value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PageLabel>(value),
    );
  }
}

String _$currentPageLabelHash() => r'a4ed13348bcd406ec3be52138cf1083106d31215';

abstract class _$CurrentPageLabel extends $Notifier<PageLabel> {
  PageLabel build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<PageLabel, PageLabel>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PageLabel, PageLabel>,
              PageLabel,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(SortNum)
const sortNumProvider = SortNumProvider._();

final class SortNumProvider extends $NotifierProvider<SortNum, int> {
  const SortNumProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sortNumProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sortNumHash();

  @$internal
  @override
  SortNum create() => SortNum();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$sortNumHash() => r'0f85ebbc77124020eaccf988c6ac9d86a7f34d7e';

abstract class _$SortNum extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(CheckIpNum)
const checkIpNumProvider = CheckIpNumProvider._();

final class CheckIpNumProvider extends $NotifierProvider<CheckIpNum, int> {
  const CheckIpNumProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'checkIpNumProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$checkIpNumHash();

  @$internal
  @override
  CheckIpNum create() => CheckIpNum();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$checkIpNumHash() => r'794de8e31e98ee4fde10509dc8f433699bff18b4';

abstract class _$CheckIpNum extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(BackBlock)
const backBlockProvider = BackBlockProvider._();

final class BackBlockProvider extends $NotifierProvider<BackBlock, bool> {
  const BackBlockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backBlockProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backBlockHash();

  @$internal
  @override
  BackBlock create() => BackBlock();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$backBlockHash() => r'c0223e0776b72d3a8c8842fc32fdb5287353999f';

abstract class _$BackBlock extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(Version)
const versionProvider = VersionProvider._();

final class VersionProvider extends $NotifierProvider<Version, int> {
  const VersionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'versionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$versionHash();

  @$internal
  @override
  Version create() => Version();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$versionHash() => r'8c0ee019d20df3f112c38ae4dc4abd61148d3809';

abstract class _$Version extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(Groups)
const groupsProvider = GroupsProvider._();

final class GroupsProvider extends $NotifierProvider<Groups, List<Group>> {
  const GroupsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'groupsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$groupsHash();

  @$internal
  @override
  Groups create() => Groups();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Group> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Group>>(value),
    );
  }
}

String _$groupsHash() => r'fbff504e0bcdb5a2770a902f2867aabd921fbadc';

abstract class _$Groups extends $Notifier<List<Group>> {
  List<Group> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<List<Group>, List<Group>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<Group>, List<Group>>,
              List<Group>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(DelayDataSource)
const delayDataSourceProvider = DelayDataSourceProvider._();

final class DelayDataSourceProvider
    extends $NotifierProvider<DelayDataSource, DelayMap> {
  const DelayDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'delayDataSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$delayDataSourceHash();

  @$internal
  @override
  DelayDataSource create() => DelayDataSource();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DelayMap value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DelayMap>(value),
    );
  }
}

String _$delayDataSourceHash() => r'9731553fb48dd89840767bf5508547d90562eb55';

abstract class _$DelayDataSource extends $Notifier<DelayMap> {
  DelayMap build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<DelayMap, DelayMap>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DelayMap, DelayMap>,
              DelayMap,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(ProxiesQuery)
const proxiesQueryProvider = ProxiesQueryProvider._();

final class ProxiesQueryProvider
    extends $NotifierProvider<ProxiesQuery, String> {
  const ProxiesQueryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'proxiesQueryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$proxiesQueryHash();

  @$internal
  @override
  ProxiesQuery create() => ProxiesQuery();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$proxiesQueryHash() => r'9f3907e06534b6882684bec47ca3ba2988297e19';

abstract class _$ProxiesQuery extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
