import 'package:flutter/material.dart';

/// 统一的应用内短时提示。
///
/// - 新提示立即替换当前提示（removeCurrentSnackBar），不排队
/// - 每条仅显示约 1 秒
/// - floating 样式
void showAppSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1200),
      ),
    );
}
