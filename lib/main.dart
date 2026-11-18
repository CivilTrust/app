import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'app/civiltrust_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Flutter Web renders to a canvas; keep the accessibility tree on so screen
  // readers (VoiceOver on iPhone Safari) can read labels and buttons.
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
  runApp(const CivilTrustApp());
}
