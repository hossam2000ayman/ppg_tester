import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';

//StatlessWidget function
class Chart extends StatelessWidget {
  final List<SensorValue> _data;

  Chart(this._data);

  /*Building chart usins sensorvalues.
  * This values will be used in homePage.dart to obtain plethysmograph wave.
  * Time dependent and value.*/
  @override
  Widget build(BuildContext context) {
    return new charts.TimeSeriesChart([
      charts.Series<SensorValue, DateTime>(
        id: 'Values',
        colorFn: (_, __) => charts.MaterialPalette.green.shadeDefault,
        domainFn: (SensorValue values, _) => values.time,
        measureFn: (SensorValue values, _) => values.value,
        data: _data,
      )
    ],
        animate: false,
        primaryMeasureAxis: charts.NumericAxisSpec(
          tickProviderSpec:
              charts.BasicNumericTickProviderSpec(zeroBound: false),
          renderSpec: charts.NoneRenderSpec(),
        ),
        domainAxis: new charts.DateTimeAxisSpec(
            renderSpec: new charts.NoneRenderSpec()));
  }
}

class SensorValue {
  final DateTime time;
  final double value;

  SensorValue(this.time, this.value);
}
