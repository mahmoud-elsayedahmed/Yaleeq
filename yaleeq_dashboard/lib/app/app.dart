import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yaleeq_dashboard/app/theme/app_theme.dart';
import 'package:yaleeq_dashboard/features/try_on/domain/repositories/try_on_repository.dart';
import 'package:yaleeq_dashboard/features/try_on/presentation/cubit/try_on_cubit.dart';
import 'package:yaleeq_dashboard/features/try_on/presentation/pages/try_on_page.dart';

class YaleeqApp extends StatelessWidget {
  const YaleeqApp({super.key, required this.repository});

  final TryOnRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yaleeq',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: BlocProvider(
        create: (_) => TryOnCubit(repository: repository)..loadModels(),
        child: const TryOnPage(),
      ),
    );
  }
}
