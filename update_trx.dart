import 'dart:io';

void main() {
  final file = File('lib/screens/transaction_history_screen.dart');
  String content = file.readAsStringSync();

  // We want to find the ListView.builder and wrap the whole condition in LayoutBuilder.
  String listStart = 'ListView.builder(';
  
  // Actually, let's just replace `ListView.builder(` with something that conditionally returns a GridView.
  // The structure is:
  //                 : ListView.builder(
  //                     padding: const EdgeInsets.all(20),
  //                     itemCount: _transactions.length,
  //                     itemBuilder: (context, index) {
  //                        ...
  //                        Widget transactionCard = ...
  //                        ...
  //                        return transactionCard;
  //                     },
  //                   ),
  
  // We can change the `Expanded(` child to a LayoutBuilder.
  // Wait, the easiest is to just find `ListView.builder(` and change it to:
  /*
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isWeb = constraints.maxWidth > 800;
                      final itemCount = _transactions.length;
                      Widget buildItem(BuildContext context, int index) {
                        // existing item builder code
                      }
                      
                      if (isWeb) {
                        return GridView.builder(
                          padding: const EdgeInsets.all(20),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 400,
                            crossAxisSpacing: 15,
                            mainAxisSpacing: 15,
                            mainAxisExtent: 130, // fixed height for the card
                          ),
                          itemCount: itemCount,
                          itemBuilder: buildItem,
                        );
                      } else {
                        return ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: itemCount,
                          itemBuilder: buildItem,
                        );
                      }
                    },
                  )
  */

  String searchStr = '''
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
''';

  String replaceStr = '''
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isWeb = constraints.maxWidth > 800;
                      final itemCount = _transactions.length;
                      
                      Widget buildItem(BuildContext context, int index) {
''';

  content = content.replaceFirst(searchStr, replaceStr);

  // Now we need to find the end of the original ListView.builder which was `},` then `),`
  // We can search for the end of the Expanded block. The `ListView.builder` is the last thing in the Expanded.
  // So it ends with:
  //                     },
  //                   ),
  //           ),
  //         ],
  //       ),
  //     );
  //   }

  String endSearchStr = '''
                      return transactionCard;
                    },
                  ),
          ),
        ],
      ),
    );
  }
''';

  String endReplaceStr = '''
                      return transactionCard;
                      }

                      if (isWeb) {
                        return GridView.builder(
                          padding: const EdgeInsets.all(20),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 500,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                            mainAxisExtent: 140,
                          ),
                          itemCount: itemCount,
                          itemBuilder: buildItem,
                        );
                      } else {
                        return ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: itemCount,
                          itemBuilder: buildItem,
                        );
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }
''';

  content = content.replaceFirst(endSearchStr, endReplaceStr);

  file.writeAsStringSync(content);
  print("Updated transaction_history_screen.dart successfully.");
}
