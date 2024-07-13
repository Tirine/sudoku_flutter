import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:sudoku_flutter/sudoku.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudoku',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a blue toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        brightness: Brightness.light,
        colorScheme:
            ColorScheme.fromSeed(seedColor: Colors.deepPurple.shade800),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple.shade200,
            brightness: Brightness.dark,
            onBackground: Colors.white),
        useMaterial3: true,
      ),
      home: const LoaderOverlay(child: SudokuPage(title: 'Sudoku')),
    );
  }
}

class SudokuPage extends StatefulWidget {
  const SudokuPage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<SudokuPage> createState() => _SudokuPageState();
}

enum DialogOptions { doNothing, startNew, restartThis }

class _SudokuPageState extends State<SudokuPage> {
  final Random _rand = Random();
  SudokuDifficulty selectedDifficulty = SudokuDifficulty.easy;
  Sudoku instance =
      Sudoku(difficulty: SudokuDifficulty.easy, initialise: false);
  Map<SudokuDifficulty, List<Future<Sudoku>>> boards = {
    SudokuDifficulty.easy: [],
    SudokuDifficulty.medium: [],
    SudokuDifficulty.hard: [],
    SudokuDifficulty.extreme: [],
  };

  Future<void>? init;
  bool note = false;
  late List<TableRow> table;
  final List<List<bool>> enabled =
      List.generate(9, (row) => List.generate(9, (col) => false));
  List<List<String>> values = List.generate(
      9, (row) => List.generate(9, (column) => ' ', growable: false),
      growable: false);
  int selectedRow = -1;
  int selectedCol = -1;
  int selectedNum = -1;

  Timer? timer;
  int timerVal = 0;

  durationToString(int duration) {
    String str = '';
    if (duration > 60) {
      str += '${(duration / 60).floor()}:';
    }
    int sec = duration % 60;
    if (sec < 10 && str.isNotEmpty) {
      str += '0$sec';
    } else {
      str += '$sec';
    }
    return str;
  }

  void update(void Function() updateFunc) {
    setState(() {
      // Something to do on each update
      updateFunc();
    });
  }

  void _initBoard(BuildContext context) {
    context.loaderOverlay.show();
    update(() {
      print(context.loaderOverlay.visible);
      // This call to update tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling update(), then the build method would not be
      // called again, and so nothing would appear to happen.
      init = instance.initialised ? Future.value() : instance.init();
      // TODO Loading overlay
      init!.then((voidVal) {
        update(() {
          // TODO Close loading overlay
          for (int i = 0; i < instance.board.length; i++) {
            for (int j = 0; j < instance.board[i].length; j++) {
              values[i][j] =
                  instance.board[i][j] == 0 ? ' ' : '${instance.board[i][j]}';
              enabled[i][j] = instance.board[i][j] == 0;
            }
          }
          timerVal = 0;
          timer?.cancel();

          timer = Timer.periodic(const Duration(seconds: 1), (timer) {
            update(() {
              timerVal = timer.tick;
            });
          });
        });
        print(context.loaderOverlay.visible);
        context.loaderOverlay.hide();
        print('!${!context.loaderOverlay.visible}');
      });
    });
  }

  void enabledCell(func, row, column, context) {
    if (enabled[row][column]) {
      func(row, column, context);
    }
  }

  void addToCell(row, column, number) {
    if (note) {
      if (instance.board[row][column] == 0) {
        if (number == 0) {
          values[row][column] = ' ';
        } else {
          var list = List<int>.from(values[row][column].codeUnits);
          list.sort();
          int unit = '$number'.codeUnits[0];
          if (list.contains(unit)) {
            list.remove(unit);
          } else {
            list.add(unit);
          }
          values[row][column] = String.fromCharCodes(list);
          print('Noted: "${values[row][column]}"');
        }
      }
    } else {
      if (number == 0 || number == instance.board[row][column]) {
        values[row][column] = ' ';
        instance.board[row][column] = 0;
      } else {
        values[row][column] = '$number';
        instance.board[row][column] = number;
      }
    }
  }

  void selectCell(row, column, context) {
    update(() {
      if (selectedNum >= 0) {
        addToCell(row, column, selectedNum);
      } else {
        // Selection
        if (selectedRow == row && selectedCol == column) {
          selectedRow = -1;
          selectedCol = -1;
        } else {
          selectedRow = row;
          selectedCol = column;
        }
      }
      verify(context);
    });
  }

  void selectNumber(number, context) {
    update(() {
      if (selectedRow >= 0) {
        addToCell(selectedRow, selectedCol, number);
      } else {
        if (selectedNum == number) {
          selectedNum = -1;
        } else {
          selectedNum = number;
        }
      }
      verify(context);
    });
  }

  void verify(context) {
    int time = timerVal;
    if (instance.filled()) {
      bool success = instance.verify();
      showDialog<DialogOptions?>(
          context: context,
          builder: (BuildContext context) {
            return SimpleDialog(
              title: Text(success ? 'Success!' : 'Something is not right...'),
              children: [
                ...(success
                    ? [Text('Time: ${durationToString(time)}')]
                    : [
                        //try again
                      ]),
                // start new
                ElevatedButton(
                  child: const Text('Go Back'),
                  onPressed: () {
                    Navigator.pop(context, DialogOptions.doNothing);
                  },
                )
              ],
            );
          }).then((value) {
        if (value != null && value != DialogOptions.doNothing) {
          if (value == DialogOptions.restartThis) {
          } else {
            _initBoard(context);
          }
        }
      });
      timer?.cancel();
      for (var list in enabled) {
        for (var i = 0; i < list.length; i++) {
          list[i] = false;
        }
      }
    }
  }

  fillLists() async {
    if (!instance.initialised) {
      Sudoku newInstance = await Sudoku.create(
          seed: instance.seed, difficulty: instance.difficulty);
      if (!instance.initialised) {
        instance = newInstance;
      }
    }

    for (var entry in boards.entries) {
      for (var i = entry.value.length; i < 3; i++) {
        Future<Sudoku> created = Sudoku.create(difficulty: entry.key, sleep: i);
        created.then(((board) {
          entry.value.add(created);
          // print('Added ${entry.key}, ${entry.value.length}');
        }));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    fillLists();
    Color? addShade(
            {Color? baseColor = Colors.transparent, transparancy = 0.85}) =>
        Color.lerp(Theme.of(context).colorScheme.onSurface, baseColor,
            transparancy);

    Color? addSelection(
            {Color? baseColor = Colors.transparent, transparancy = 0.5}) =>
        Color.lerp(Theme.of(context).colorScheme.onSurface, baseColor,
            transparancy);

    Color? addHighlight(
            {Color? baseColor = Colors.transparent, transparancy = 0.85}) =>
        Color.lerp(
            Theme.of(context).colorScheme.onSecondary, baseColor, transparancy);
    // This method is rerun every time update is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    Size mediaSize = MediaQuery.of(context).size;
    double fontSize = min(mediaSize.height, mediaSize.width) / 18;
    table = List.generate(
        9,
        (row) => TableRow(
            children: List.generate(
                9,
                (column) => GestureDetector(
                    onTap: () => enabledCell(selectCell, row, column, context),
                    child: Container(
                        decoration: BoxDecoration(
                            border: column % 3 == 2
                                ? const Border(right: BorderSide(width: 4))
                                : column == 0
                                    ? const Border(left: BorderSide(width: 4))
                                    : null,
                            color: column % 3 == 1
                                ? addShade(
                                    baseColor: (selectedRow == row &&
                                            selectedCol == column)
                                        ? addSelection()
                                        : Colors.transparent)
                                : (selectedRow == row && selectedCol == column)
                                    ? addSelection()
                                    : null),
                        child: (enabled[row][column] &&
                                values[row][column].length > 1)
                            ? Table(
                                children: List<TableRow>.generate(
                                    3,
                                    (intRow) => TableRow(
                                        children: List<Text>.generate(
                                            3,
                                            (intCol) => Text(
                                                values[row][column].contains(
                                                        '${(intRow * 3 + intCol) + 1}')
                                                    ? '${(intRow * 3 + intCol) + 1}'
                                                    : ' ',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: fontSize / 3,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                ))))))
                            : Text(
                                values[row][column],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: fontSize,
                                    color: enabled[row][column]
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .tertiary),
                              ))),
                growable: false),
            decoration: BoxDecoration(
                border: row % 3 == 2
                    ? const Border(bottom: BorderSide(width: 4))
                    : (row == 0
                        ? const Border(top: BorderSide(width: 4))
                        : null),
                color: row % 2 == 0 ? addShade() : null)),
        growable: false);
    List<ElevatedButton> numbers = List.generate(
        9,
        (index) => ElevatedButton(
              onPressed: () => selectNumber(index + 1, context),
              style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                      (states) =>
                          selectedNum == (index + 1) ? addSelection() : null)),
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: fontSize / 2),
              ),
            ));
    ElevatedButton noteButton = ElevatedButton(
        onPressed: () => update(() {
              note = !note;
            }),
        style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                (states) => (note ? addSelection() : null))),
        child: Icon(
          Icons.edit,
          size: fontSize * 1.2,
        ));
    List<Widget> secondRow = [
      const Spacer(),
      const Text('Difficulty: '),
      DropdownButton<SudokuDifficulty>(
        items: SudokuDifficulty.values
            .map<DropdownMenuItem<SudokuDifficulty>>((e) => DropdownMenuItem(
                value: e,
                child: Text(e.name[0].toUpperCase() + e.name.substring(1))))
            .toList(),
        onChanged: (value) {
          update(() {
            if (value != selectedDifficulty &&
                value != null &&
                boards[value] != null) {
              int index = _rand.nextInt(boards[value]!.length - 1);
              boards[value]![index].then((val) {
                instance = val;
                boards[value]!.removeAt(index);
                update(() {
                  selectedDifficulty = value;
                });
              });
            }
          });
        },
        value: selectedDifficulty,
      ),
      const Spacer(),
      Text(timer != null ? 'Time: ${durationToString(timerVal)}' : ''),
      const Spacer(),
    ];
    return Scaffold(
      // appBar: AppBar(
      //   // TRY THIS: Try changing the color here to a specific color (to
      //   // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
      //   // change color while the other colors stay the same.
      //   backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      //   // Here we take the value from the MyHomePage object that was created by
      //   // the App.build method, and use it to set our appbar title.
      //   title: Text(widget.title),
      // ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Spacer(),
            FractionallySizedBox(
                child: Row(children: [
              const Spacer(flex: 2),
              TextField(
                  decoration: InputDecoration(
                      constraints: BoxConstraints(
                          maxWidth: mediaSize.width /
                              (mediaSize.height >= mediaSize.width ? 1 : 2)),
                      labelText: 'Current ID: ${instance.seed}'),
                  keyboardType: const TextInputType.numberWithOptions(
                      signed: true, decimal: false),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onSubmitted: (value) async {
                    int? newSeed = int.tryParse(value);
                    if (newSeed != null) {
                      context.loaderOverlay.show();
                      instance = await Sudoku.create(
                          seed: newSeed, difficulty: selectedDifficulty);

                      _initBoard(context);
                    }
                  }),
              ...(mediaSize.height < mediaSize.width ? secondRow : []),
              const Spacer(),
            ])),
            ...(mediaSize.height >= mediaSize.width
                ? [Row(children: secondRow)]
                : []),
            const Spacer(),
            Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: table,
            ),
            const Spacer(),
            Row(children: [
              const Spacer(),
              ...(mediaSize.height > mediaSize.width
                  ? numbers.sublist(0, (numbers.length / 2).floor())
                  : numbers),
              const Spacer(),
              ElevatedButton(
                  onPressed: () => selectNumber(0, context),
                  style: ButtonStyle(
                      backgroundColor:
                          WidgetStateProperty.resolveWith<Color?>((states) =>
                              (selectedNum == 0 ? addSelection() : null))),
                  child: Icon(
                    Icons.highlight_remove,
                    size: fontSize,
                  )),
              ...(mediaSize.height > mediaSize.width ? [] : [noteButton]),
              const Spacer(),
            ]),
            ...(mediaSize.height > mediaSize.width
                ? [
                    Row(children: [
                      const Spacer(),
                      ...numbers.sublist((numbers.length / 2).floor()),
                      const Spacer(),
                      noteButton,
                      const Spacer()
                    ]),
                    const Spacer()
                  ]
                : [const Spacer()])
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _initBoard(context),
        tooltip: 'Start new',
        child: const Icon(Icons.restart_alt),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
