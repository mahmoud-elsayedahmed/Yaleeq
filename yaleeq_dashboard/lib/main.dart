import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaleeq_dashboard/app/app.dart';
import 'package:yaleeq_dashboard/core/network/api_client.dart';
import 'package:yaleeq_dashboard/features/try_on/data/datasources/try_on_remote_datasource.dart';
import 'package:yaleeq_dashboard/features/try_on/data/repositories/try_on_repository_impl.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  // Wire dependencies — no DI framework needed at this stage.
  final dio = ApiClient.create();
  final dataSource = TryOnRemoteDataSource(dio);
  final repository = TryOnRepositoryImpl(dataSource);

  runApp(YaleeqApp(repository: repository));
}
