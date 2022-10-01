//We imported our packages.
import 'dart:async';

//Camera package to be able to use camera.
import 'package:camera/camera.dart';
//Widgets like buttons, graphics etc.
import 'package:flutter/material.dart';
//Prevent screen for locking
import 'package:wakelock/wakelock.dart';

//Calculations
import 'chart.dart';

class HomePage extends StatefulWidget {
  @override
  HomePageView createState() {
    return HomePageView();
  }
}

class HomePageView extends State<HomePage> with SingleTickerProviderStateMixin {
  bool _toggled =
      false; // Button toggle value, Heart button will be disabled at first launch.
  List<SensorValue> _data =
      []; // array to store sensor the values
  CameraController
      ?_controller; //Camera controllers domain specified as _controller. So we will use -controller to use camera.
  double _alpha = 0.3; // factor for the mean value
  AnimationController ?_animationController;
  double _iconScale = 1;
  int _bpm = 0; // Beats per minute set to '0'.
  int _fs =
      30; //Sampling Frequency . This option is '30' because not every camera can provide more than 30 frames per second.
  int _windowLen = 30 * 6; // window length to display - 6 seconds
  CameraImage ?_image; // Store the last camera image
  double ?_avg; // Store the average value during calculation
  DateTime ?_now; // Store the now Datetime
  Timer ?_timer; // Timer for image processing

  //Interface related. How often waveform is sync.
  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(duration: Duration(milliseconds: 500), vsync: this);
    _animationController
      !..addListener(() {
        setState(() {
          _iconScale = 1.0 + _animationController!.value * 0.4;
        });
      });
  }

  @override
  void dispose() {
    _timer!.cancel();
    _toggled = false;
    _disposeController();
    Wakelock.disable();
    _animationController!.stop();
    _animationController!.dispose();
    super.dispose();
  }

  //Full interface codes.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
                flex: 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.all(
                            Radius.circular(18),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            alignment: Alignment.center,
                            children: <Widget>[
                              _controller != null && _toggled
                                  ? AspectRatio(
                                      aspectRatio:
                                          _controller!.value.aspectRatio,
                                      child: CameraPreview(_controller!),
                                    )
                                  : Container(
                                      padding: EdgeInsets.all(12),
                                      alignment: Alignment.center,
                                      color: Colors.grey,
                                    ),
                              Container(
                                alignment: Alignment.center,
                                padding: EdgeInsets.all(4),
                                child: Text(
                                  _toggled
                                      ? "Cover camera and flashlight with finger"
                                      : "Photodetector Feed",
                                  style: TextStyle(
                                      backgroundColor: _toggled
                                          ? Colors.white
                                          : Colors.transparent),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Center(
                          child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            "Estimated HR",
                            style: TextStyle(
                                fontSize: 18,
                                color: Colors.red,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            (_bpm > 30 && _bpm < 150
                                ? _bpm.toString()
                                : "Waiting..."),
                            style: TextStyle(
                                fontSize: 36, fontWeight: FontWeight.bold),
                          ),
                        ],
                      )),
                    ),
                  ],
                )),
            Expanded(
              flex: 1,
              child: Center(
                child: Transform.scale(
                  scale: _iconScale,
                  child: IconButton(
                    icon:
                        Icon(_toggled ? Icons.favorite : Icons.favorite_border),
                    color: Colors.green,
                    iconSize: 128,
                    onPressed: () {
                      if (_toggled) {
                        _untoggle();
                      } else {
                        _toggle();
                      }
                    },
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                margin: EdgeInsets.all(12),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(
                      Radius.circular(18),
                    ),
                    color: Colors.black),
                child: Chart(_data),
              ),
            ),
          ],
        ),
      ),
    );
  }
//FUNCTIONS

  //
  void _clearData() {
    // Create array of 128 ~= 255/2
    _data.clear();
    int now = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < _windowLen; i++)
      _data.insert(
          0,
          SensorValue(
              DateTime.fromMillisecondsSinceEpoch(now - i * 1000 ~/ _fs), 128));
  }

  //When button toggled.
  void _toggle() {
    _clearData();
    _initController().then((onValue) {
      Wakelock.enable();
      //_animationController?.repeat(reverse: true); --Animation stopped
      setState(() {
        _toggled = true;
      });
      // after is toggled
      _initTimer();
      _updateBPM();
    });
  }

  //After button is Untoggled.
  void _untoggle() {
    _disposeController();
    Wakelock.disable();
    _animationController!.stop();
    _animationController!.value = 0.0;
    setState(() {
      _toggled = false;
    });
  }

  //Reset values after button is untoggled.
  void _disposeController() {
    _controller!.dispose();
    
  }

  /* We was set frames per second to 30, this is because of we don't need to process every single frame
  * we set _processing boolean to false at first, when we receieve scanned image _processing become true
  * after processing is finished it is turn back to false in every 1/30 second. */
  Future<void> _initController() async {
    try {
      List _cameras = await availableCameras();
      _controller = CameraController(_cameras.first, ResolutionPreset.low);
      await _controller!.initialize();
      Future.delayed(Duration(milliseconds: 100)).then((onValue) {
        //BUG FIX; FLASHLIGT WASN'T WORKING
        //old: _controller.flash(true);
        _controller!.setFlashMode(FlashMode.torch);
      });
      //Image stream is started and taken frames are stored in _image array.
      _controller!.startImageStream((CameraImage image) {
        _image = image;
      });
      //Catch exception errors and display them. Major code for bug fixing.
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  //Timer start.
  void _initTimer() {
    _timer = Timer.periodic(Duration(milliseconds: 1000 ~/ _fs), (timer) {
      if (_toggled) {
        if (_image != null) _scanImage(_image!);
      } else {
        timer.cancel();
      }
    });
  }

  //Image scanning.
  /* This function calculates the average of the frames' red channels (RGB values)
  * and add them to the data list. 50 values are stored, while new one is added last one is
  * deleted from the data list(array). */
  void _scanImage(CameraImage image) {
    //Datetime
    _now = DateTime.now();
    //Average RGB value stored in _avg array.
    _avg =
        image.planes.first.bytes.reduce((value, element) => value + element) /
            image.planes.first.bytes.length;
    if (_data.length >= _windowLen) {
      _data.removeAt(0);
    }
    setState(() {
      _data.add(SensorValue(_now!, _avg!));
    });
  }

  void _updateBPM() async {
    //Heart rate calculations.
    //Taken sensor values
    List<SensorValue> _values;
    //Average HR values
    double _avg;
    //for for loop.
    int _n;
    double _m;
    //treshold value
    double _threshold;
    //BPM value
    double _bpm;
    int _counter;
    int _previous;
    //while button is toggled.
    while (_toggled) {
      _values = List.from(_data); // sensor values obtained as array _data
      _avg = 0; //average heart rate
      _n = _values.length; //lenght of sensor values
      _m = 0;
      //loop will stay until values ended
      _values.forEach((SensorValue value) {
        //average value = amplitude(value.value) / _n(lenght of values)
        _avg += value.value / _n;
        //_m=0; if value > 0; _m = amplitude(value.value)
        if (value.value > _m) _m = value.value;
      });
      //threshold in order to keep efficiency
      _threshold = (_m + _avg) / 2;
      _bpm = 0;
      _counter = 0;
      _previous = 0;
      for (int i = 1; i < _n; i++) {
        if (_values[i - 1].value < _threshold &&
            _values[i].value > _threshold) {
          if (_previous != 0) {
            _counter++;
            //bpm = 60*1000 / sensor value*1000 - _previous(previously obtained bpm)
            _bpm += 60 *
                1000 /
                (_values[i].time.millisecondsSinceEpoch - _previous);
          }
          _previous = _values[i].time.millisecondsSinceEpoch;
        }
      }
      if (_counter > 0) {
        _bpm = _bpm / _counter;
        print(_bpm);
        setState(() {
          this._bpm = ((1 - _alpha) * this._bpm + _alpha * _bpm).toInt();
        });
      }
      await Future.delayed(Duration(
          milliseconds:
              1000 * _windowLen ~/ _fs)); // wait for a new set of _data values/
    }
  }
}
