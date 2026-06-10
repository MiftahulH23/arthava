import 'dart:io';

void main() {
  final file = File('lib/screens/stats_screen.dart');
  String content = file.readAsStringSync();

  // Part 1: Replace the start of the SingleChildScrollView>Column
  String searchStart = '''
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 250,
                          child: Stack(
''';

  String replaceStart = '''
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWeb = constraints.maxWidth > 800;
                        final chartAndSummary = Column(
                          children: [
                            SizedBox(
                              height: isWeb ? 320 : 250,
                              child: Stack(
''';

  content = content.replaceFirst(searchStart, replaceStart);

  // Part 2: Close chartAndSummary and open categoryList before ...List.generate
  String searchMiddle = '''
                        const SizedBox(height: 20),

                        ...List.generate(_categoryData.length, (index) {
''';

  String replaceMiddle = '''
                          ],
                        ); // end of chartAndSummary

                        final categoryList = Column(
                          children: [
                            ...List.generate(_categoryData.length, (index) {
''';

  content = content.replaceFirst(searchMiddle, replaceMiddle);

  // Part 3: Close categoryList and return Row or Column at the end
  String searchEnd = '''
                          );
                        }),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
''';

  String replaceEnd = '''
                          );
                        }),
                      ],
                    ); // end of categoryList

                    if (isWeb) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 4, child: chartAndSummary),
                          const SizedBox(width: 40),
                          Expanded(flex: 6, child: categoryList),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          chartAndSummary,
                          const SizedBox(height: 20),
                          categoryList,
                        ],
                      );
                    }
                  },
                ),
              ),
          ),
        ],
      ),
    );
  }
}
''';

  content = content.replaceFirst(searchEnd, replaceEnd);

  file.writeAsStringSync(content);
  print("Updated stats_screen.dart successfully without syntax errors.");
}
