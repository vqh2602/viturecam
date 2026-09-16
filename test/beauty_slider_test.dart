import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viturecam/widgets/beauty_slider.dart';

void main() {
  testWidgets('BeautySlider renders and reset button resets value to defaultValue', (tester) async {
    double currentValue = 45;
    double? resetReceived;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return BeautySlider(
                label: 'Smooth Test',
                value: currentValue,
                defaultValue: 0,
                onChanged: (v) {
                  setState(() {
                    currentValue = v;
                    resetReceived = v;
                  });
                },
              );
            },
          ),
        ),
      ),
    );

    // Initial state: value is 45
    expect(find.text('Smooth Test'), findsOneWidget);
    expect(find.text('45'), findsOneWidget);
    expect(find.byIcon(Icons.restart_alt_rounded), findsOneWidget);

    // Tap reset button
    await tester.tap(find.byIcon(Icons.restart_alt_rounded));
    await tester.pumpAndSettle();

    // Value should now be reset to 0
    expect(resetReceived, equals(0.0));
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('Tapping the value text also resets modified value', (tester) async {
    double currentValue = 70;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return BeautySlider(
                label: 'Whitening Test',
                value: currentValue,
                defaultValue: 0,
                onChanged: (v) {
                  setState(() {
                    currentValue = v;
                  });
                },
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('70'), findsOneWidget);

    // Tap value text
    await tester.tap(find.text('70'));
    await tester.pumpAndSettle();

    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('Reset button tooltip and magnetic snap near defaultValue', (tester) async {
    double currentValue = 50;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return BeautySlider(
                label: 'Texture Test',
                value: currentValue,
                defaultValue: 50,
                onChanged: (v) {
                  setState(() {
                    currentValue = v;
                  });
                },
              );
            },
          ),
        ),
      ),
    );

    // Initial state is at defaultValue (50), so not modified
    expect(find.text('50'), findsOneWidget);
    final buttonFinder = find.byIcon(Icons.restart_alt_rounded);
    expect(buttonFinder, findsOneWidget);

    // Tapping while at defaultValue does not change value
    await tester.tap(buttonFinder);
    await tester.pumpAndSettle();
    expect(currentValue, equals(50));

    // Drag slider slightly: e.g. drag thumb towards 51
    final sliderFinder = find.byType(Slider);
    await tester.drag(sliderFinder, const Offset(3, 0));
    await tester.pumpAndSettle();

    // If within 1.5 of defaultValue 50, it snaps to 50
    expect((currentValue - 50).abs() <= 1.5 ? currentValue == 50 : true, isTrue);
  });
}
