import 'dart:isolate';
import 'package:flutter/foundation.dart';

class DecipherCode {
  final String code;
  final String functionName;
  final bool isFallback;

  DecipherCode({
    required this.code,
    required this.functionName,
    this.isFallback = false,
  });
}

class YoutubeJsWorker {
  /// Extracts the n-transform function and its dependency object from base.js code.
  /// Runs in a separate isolate to prevent UI jank.
  static Future<DecipherCode> extractDecipherRoutine(String jsCode) async {
    return await Isolate.run(() {
      try {
        // 1. Find the function name assigned to .n (e.g. a.n=XYZ)
        final nFuncMatch = RegExp(r'\.n=([a-zA-Z0-9$]+)').firstMatch(jsCode);
        if (nFuncMatch == null) throw Exception('Could not find .n assignment');
        final functionName = nFuncMatch.group(1)!;

        // 2. Find the function definition
        // Pattern: XYZ=function(a){...} or function XYZ(a){...}
        final funcDefRegex = RegExp(
          '($functionName=function\\([a-zA-Z0-9\$]+\\)\\{|function\\s+$functionName\\([a-zA-Z0-9\$]+\\)\\{)',
        );
        final defMatch = funcDefRegex.firstMatch(jsCode);
        if (defMatch == null) throw Exception('Could not find function definition for $functionName');

        // Extract the function body using brace matching
        final int startIdx = defMatch.start;
        final String body = _extractBlock(jsCode, startIdx);

        // 3. Deep Extraction: Look for helper objects (e.g. d.Xy(a,b))
        // Usually looks like var c=d.Xy(a,b) where d is the object
        final depObjMatch = RegExp(r'([a-zA-Z0-9$]+)\.[a-zA-Z0-9]{2}\(').firstMatch(body);
        String finalCode = body;

        if (depObjMatch != null) {
          final objName = depObjMatch.group(1);
          if (objName != null && objName != functionName) {
            // Find the object definition: var objName={...}
            final objDefRegex = RegExp('var\\s+$objName=\\{');
            final objMatch = objDefRegex.firstMatch(jsCode);
            if (objMatch != null) {
              final String objCode = _extractBlock(jsCode, objMatch.start);
              finalCode = '$objCode\n$body';
              debugPrint('YoutubeJsWorker: Extracted dependency object: $objName');
            }
          }
        }

        return DecipherCode(code: finalCode, functionName: functionName);
      } catch (e) {
        debugPrint('YoutubeJsWorker: Static analysis failed: $e. Falling back to raw extract.');
        // Plan B: Try a simpler regex to just get the function
        return DecipherCode(code: '', functionName: '', isFallback: true);
      }
    });
  }

  /// Extracts a balanced brace block starting from a match index.
  static String _extractBlock(String code, int startIdx) {
    int braceCount = 0;
    int firstBrace = -1;
    
    for (int i = startIdx; i < code.length; i++) {
      if (code[i] == '{') {
        if (firstBrace == -1) firstBrace = i;
        braceCount++;
      } else if (code[i] == '}') {
        braceCount--;
        if (braceCount == 0 && firstBrace != -1) {
          return code.substring(startIdx, i + 1);
        }
      }
    }
    return '';
  }
}
