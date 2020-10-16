import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' as image_picker;
import 'package:modal_progress_hud/modal_progress_hud.dart';
import 'package:toonify/components/custom_image_box.dart';
import 'package:toonify/components/custom_round_button.dart';
import 'package:dio/dio.dart' as dio;
import 'package:http_parser/http_parser.dart';
import 'package:after_init/after_init.dart';
import 'package:share/share.dart';
import 'package:image/image.dart' as Img;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with AfterInitMixin<MainScreen> {
  bool _showSpinner = false; //spinner for processing image
  bool _isImageProcessed = false;

  File _inputImage;
  final _imagePicker = image_picker.ImagePicker();

  Response _apiResponse;
  String _outputImageUrl;
  http.Response _outputImageUrlResponse;
  Image _outputImage;

  double _screenWidth;
  double _screenHeight;

  String _uploadError;
  String _savedLocation;

  // Pick image from gallery/camera
  Future<void> _pickImage(image_picker.ImageSource source) async {
    final pickedFile = await _imagePicker.getImage(
      source: source,
      preferredCameraDevice: image_picker.CameraDevice.front,
      maxWidth: 960,
      maxHeight: 1280,
    );

    if (pickedFile != null) {
      setState(() {
        _inputImage = null;
        _outputImageUrl = null;
        _outputImage = null;
        _uploadError = null;
        _isImageProcessed = false;
        _inputImage = File(pickedFile.path);
      });
      await _postImage(_inputImage.path);
    } else {
      print('No image selected');
    }
  }

  // Post image to Toonify api
  void _postImage(String imagePath) async {
    try {
      var dioRequest = dio.Dio();
      dioRequest.options.baseUrl = 'https://api.deepai.org/api/toonify';
      dioRequest.options.headers = {
        'api-key': 'YOUR_API_KEY',
      };

      var formData = new dio.FormData();

      var file = await dio.MultipartFile.fromFile(imagePath,
          filename: imagePath, contentType: MediaType('image', imagePath));

      formData.files.add(MapEntry('image', file));

      setState(() {
        _showSpinner = true;
      });
      _apiResponse = await dioRequest.post(
        dioRequest.options.baseUrl,
        data: formData,
        options: Options(responseType: ResponseType.json),
      );

      _outputImageUrl = json.decode(_apiResponse.toString())['output_url'];

      _outputImageUrlResponse = await http.get(
        _outputImageUrl,
      );

      setState(() {
        _outputImage = Image.network(
          _outputImageUrl,
          loadingBuilder: (BuildContext context, Widget child,
              ImageChunkEvent loadingProgress) {
            if (loadingProgress == null) {
              return child;
            } else if (loadingProgress.cumulativeBytesLoaded ==
                loadingProgress.expectedTotalBytes) {
              Future.delayed(Duration.zero, () async {
                setState(() {
                  _isImageProcessed = true;
                  _showSpinner = false;
                  _uploadError = null;
                });
              });
            }
            return Container();
          },
        );
      });
    } catch (err) {
      setState(() {
        _showSpinner = false;
      });
      print('ERROR  $err');
      _uploadError = err.toString();
    }
  }

  void _showSnackBar(BuildContext context, String text) {
    final snackBar = SnackBar(content: Text(text));
    Scaffold.of(context).showSnackBar(snackBar);
  }

  Future<bool> _saveImage() async {
    Img.Image image = Img.decodeImage(_outputImageUrlResponse.bodyBytes);

    PermissionStatus status = await Permission.storage.request();

    if (status.isGranted) {
      final result = await ImageGallerySaver.saveImage(
          Uint8List.fromList(Img.encodeJpg(image)),
          quality: 100,
          name: 'toonified');

      _savedLocation = result.toString().replaceAll('file://', '');

      return true;
    }
    return false;
  }

  void _shareImage() async {
    bool result = await _saveImage();

    if (result) {
      Share.shareFiles([_savedLocation], text: 'Toonify your selfie !!!');
    } else {
      print('Error: could not get the image');
    }
  }

  @override
  void didInitState() {
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Toonify Your Selfie',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 30,
          ),
        ),
        backgroundColor: Color(0xff01A0C7),
      ),
      body: ModalProgressHUD(
        inAsyncCall: _showSpinner,
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    'Upload your full face photo for the best result',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                      fontSize: 15.0,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CustomImageBox(
                        width: _screenWidth / 2.1,
                        height: _screenHeight / 3,
                        image: _inputImage != null
                            ? Image.file(_inputImage)
                            : Container(),
                      ),
                      CustomImageBox(
                        width: _screenWidth / 2.1,
                        height: _screenHeight / 3,
                        image: _outputImage != null
                            ? _outputImage
                            : (_uploadError == null
                                ? Container()
                                : Center(
                                    child: Container(
                                      child: Text(
                                        'Not a valid Input Image',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  )),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      CustomRoundButton(
                        iconData: Icons.image,
                        color: Colors.green,
                        onPressed: () =>
                            _pickImage(image_picker.ImageSource.gallery),
                      ),
                      CustomRoundButton(
                        iconData: Icons.camera,
                        color: Colors.blue,
                        onPressed: () =>
                            _pickImage(image_picker.ImageSource.camera),
                      ),
                      _isImageProcessed
                          ? Builder(
                              builder: (context) {
                                return CustomRoundButton(
                                    iconData: Icons.save_alt,
                                    color: Colors.red,
                                    onPressed: () async {
                                      bool result = await _saveImage();
                                      if (result) {
                                        _showSnackBar(context,
                                            'Image is saved to gallery');
                                      } else {
                                        _showSnackBar(context,
                                            'Error occured in saving the image');
                                      }
                                    });
                              },
                            )
                          : Container(),
                      _isImageProcessed
                          ? CustomRoundButton(
                              iconData: Icons.share,
                              color: Colors.yellow,
                              onPressed: () => _shareImage(),
                            )
                          : Container(),
                    ],
                  ),
                ),
              ],
            ),
            _showSpinner
                ? Center(
                    child: Text(
                      'Processing ...',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w700,
                        fontSize: 20.0,
                      ),
                    ),
                  )
                : Container(),
          ],
        ),
      ),
    );
  }
}
