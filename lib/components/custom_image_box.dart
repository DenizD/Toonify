import 'package:flutter/material.dart';

class CustomImageBox extends StatelessWidget {
  final double width;
  final double height;
  final Widget image;

  CustomImageBox({this.width, this.height, this.image});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.lightBlueAccent, width: 10),
        borderRadius: BorderRadius.circular(10),
      ),
      width: width,
      height: height,
      child: image,
    );
  }
}
