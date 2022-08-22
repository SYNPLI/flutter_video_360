class Video360PlayInfo {
  int duration = 0;
  int total = 0;
  bool isPlaying = false;
  double compassAngle = 0.0;

  Video360PlayInfo({
    required this.duration,
    required this.total,
    required this.isPlaying,
    this.compassAngle = 0.0,
  });
}
