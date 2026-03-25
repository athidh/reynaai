import 'dart:io';

void main() {
  final file = File('analyze_utf8.txt');
  final lines = file.readAsLinesSync();
  final constErrors = lines.where((l) => 
    l.contains('invalid_constant') || 
    l.contains('non_constant_default_value')
  );
  
  int fixedCount = 0;

  for (final err in constErrors) {
    try {
      // e.g. "  error - lib\main.dart:69:27 - MESSAGE"
      final parts = err.split(' - ');
      if (parts.length >= 2) {
        final location = parts[1].trim(); // "lib\main.dart:69:27"
        final locParts = location.split(':');
        final filePath = locParts[0];
        final lineNum = int.parse(locParts[1]);
        
        final file = File(filePath);
        if (!file.existsSync()) continue;
        
        final fileLines = file.readAsLinesSync();
        
        // Go backward from lineNum (1-indexed) to find 'const' and remove it
        for (int i = lineNum - 1; i >= 0 && i >= lineNum - 15; i--) {
          if (fileLines[i].contains('const ')) {
            // First try matching exact occurrences
            if (fileLines[i].contains('const AppColors')) {
                fileLines[i] = fileLines[i].replaceFirst('const AppColors', 'AppColors');
                file.writeAsStringSync(fileLines.join('\n'));
                fixedCount++;
                break;
            } else {
                fileLines[i] = fileLines[i].replaceFirst('const ', '');
                file.writeAsStringSync(fileLines.join('\n'));
                fixedCount++;
                break;
            }
          }
        }
      }
    } catch (e) {
      print('Error parsing line: $e');
    }
  }
  
  print('Removed const modifier in $fixedCount locations.');
}
