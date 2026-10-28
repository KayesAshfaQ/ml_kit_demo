class PredictionModel {
  const PredictionModel({required this.label, required this.confidence});

  final String label;
  // Probability in the range 0–1, after dequantizing integer model outputs.
  final double confidence;
}
