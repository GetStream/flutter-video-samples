// lib/env/env.dart
import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '../../.env')
abstract class Env {
  @EnviedField(varName: 'SAMPLE_STREAM_VIDEO_API_KEY')
  static const String streamVideoApiKey = _Env.streamVideoApiKey;

  @EnviedField(varName: 'SAMPLE_USER_00_ID')
  static const String sampleUserId00 = _Env.sampleUserId00;
  @EnviedField(varName: 'SAMPLE_USER_00_NAME')
  static const String sampleUserName00 = _Env.sampleUserName00;
  @EnviedField(varName: 'SAMPLE_USER_00_ROLE')
  static const String sampleUserRole00 = _Env.sampleUserRole00;
  @EnviedField(varName: 'SAMPLE_USER_00_IMAGE')
  static const String sampleUserImage00 = _Env.sampleUserImage00;
  @EnviedField(varName: 'SAMPLE_USER_00_VIDEO_TOKEN')
  static const String sampleUserVideoToken00 = _Env.sampleUserVideoToken00;
}
