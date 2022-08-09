import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';


import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:ql_wristband/ql_wristband.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  late DecodeController _decodeController;
  List<String> dataSource = <String>[];
  @override
  void initState() {
    super.initState();
    _decodeController = DecodeController(responseCallback: (BaseResponse response) {
      if (response.command == wifiConfigInfoCommand) {
        final configResponse = WifiConfigResponse(length: response.length, data: response.data!);

        dataSource.add(configResponse.toString());
        setState(() {

        });
      } else if(response.command == deviceInfoCommand) {
        final configResponse = DeviceStatusResponse(length: response.length, data: response.data!);
        // print('当前设备信息 ${configResponse.toString()}');
        dataSource.add(configResponse.toString());
        setState(() {

        });
      } else if(response.command == realTimeDataCommand) {
        final configResponse = RealTimeDataResponse(length: response.length, data: response.data!);
        // print('实时心率数据 ${configResponse.toString()}');
        dataSource.add(configResponse.toString());
        setState(() {

        });
      }
    });
    _flutterReactiveBle.statusStream.listen((event) {
      if(event == BleStatus.ready) {
        _scanDevice();
      }
    });
    // _requestBlePermission();

  }
  @override
  void dispose(){
    _decodeController.close();
    super.dispose();
  }
  Future<void> _requestBlePermission() async {
    final status = await Permission.location.status;
    if (status.isGranted) {
      // 有蓝牙权限
      _scanDevice();
    } else {
      if (await Permission.location.request().isGranted) {
        // Either the permission was already granted before or the user just granted it.
        _scanDevice();
      }
    }
  }
  final _flutterReactiveBle = FlutterReactiveBle();
  StreamSubscription<DiscoveredDevice>? _scanStream;
  void _scanDevice() {
    _scanStream = _flutterReactiveBle.scanForDevices(withServices: [], scanMode: ScanMode.lowLatency).listen((device) {
      //code for handling results
      if (kDebugMode) {
        print('当前设备名称${device.name}');
      }
      if(device.name.contains('CL910L')) {
        _scanStream?.cancel();
        _connectDevice(device);
      }
    }, onError: (dynamic e) {
      //code for handling error
      if (kDebugMode) {
        print('扫描失败$e');
      }
    });
  }
  DiscoveredDevice? _device;
  void _connectDevice(DiscoveredDevice device) {
    _flutterReactiveBle.connectToDevice(id: device.id).listen((event) {
      if(event.connectionState == DeviceConnectionState.connected) {
        _device = device;
        _notifyCharacteristic();
      }
    }).onError((dynamic e){
      if (kDebugMode) {
        print('连接失败$e');
      }
    });
  }
  Future<void> _notifyCharacteristic() async {
    final characteristic = QualifiedCharacteristic(serviceId: Uuid.parse('aae28f00-71b5-42a1-8c3c-f9cf6ac969d0'), characteristicId: Uuid.parse('aae28f01-71b5-42a1-8c3c-f9cf6ac969d0'), deviceId: _device!.id);
    _flutterReactiveBle.subscribeToCharacteristic(characteristic).listen((data) {

      _decodeController.receiveResponseData(data);
    }, onError: (dynamic error) {
      // code to handle errors
    });
  }
  void _writeCommand(List<int> list) {
    final characteristic = QualifiedCharacteristic(serviceId: Uuid.parse('aae28f00-71b5-42a1-8c3c-f9cf6ac969d0'), characteristicId: Uuid.parse('aae28f02-71b5-42a1-8c3c-f9cf6ac969d0'), deviceId: _device!.id);
    _flutterReactiveBle.writeCharacteristicWithoutResponse(characteristic, value: list).then((value){
      if (kDebugMode) {
        print('写入命令成功');
      }
    }).catchError((dynamic e){
      if (kDebugMode) {
        print('写入命令失败$e');
      }
    });
  }
  Widget _topButton(String text,GestureTapCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.red,
        height: 30,
        width: 100,
        alignment: Alignment.center,
        child: Text(text),
      ),
    );
  @override
  Widget build(BuildContext context) => MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Column(children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _topButton('配置wifi', () {
                final request = ConfigWifiRequest(url: '192.168.0.71', port: 9125, ssid: 'Hi-visbody', password: 'abcd.123456');
                _writeCommand(EncodeFactory.encodeData(request));
              }),
              _topButton('获取wifi', () {
                _writeCommand(EncodeFactory.encodeData(DefaultRequest(command: wifiConfigInfoCommand)));
              }),
              _topButton('清除ID', () {
                _writeCommand(EncodeFactory.encodeData(DefaultRequest(command: clearDeviceID)));
              }),
              _topButton('配置ID', () {
                _writeCommand(EncodeFactory.encodeData(ConfigDeviceRequest()));
              }),
              _topButton('打开蓝牙', _flutterReactiveBle.setBleState),
            ],
          ),
          Expanded(child: ListView.builder(itemBuilder: (BuildContext context, int index)=> Container(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 15),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFECECEC), width: 1))
              ),
              child: Text(dataSource[index]),
            ), itemCount: dataSource.length,))
        ],),
      ),
    );
}
