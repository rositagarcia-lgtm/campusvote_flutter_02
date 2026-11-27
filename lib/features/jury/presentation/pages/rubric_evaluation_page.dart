import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_appbar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_palette.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/app_motion.dart';
import '../../../../core/widgets/app_notice.dart';
import '../../../../core/widgets/app_page_layout.dart';
import '../../../../core/widgets/app_status_chip.dart';
import '../../../../core/widgets/translatable_text.dart';
import '../../../settings/presentation/settings_copy.dart';
import '../../../student_projects/presentation/widgets/project_visuals.dart';
import '../../data/models/jury_models.dart';
import '../providers/jury_providers.dart';
import '../providers/jury_state.dart';
import '../widgets/project_status_chip.dart';
import '../widgets/rubric_criterion_tile.dart';
import '../widgets/rubric_form_widgets.dart';

/// `/jury/fair/:fairId/project/:projectId/rubric`
///
/// Formulario dinámico sobre `rubric.criteria[]`. El control es un
/// interruptor porque el backend guarda un checklist (`checked`), calcula el
/// score 0–20 y rechaza con 400 cualquier campo extra (`schema .strict()`),
/// por eso no hay slider ni comentario por criterio.
class RubricEvaluationPage extends ConsumerStatefulWidget {
  const RubricEvaluationPage({
    super.key,
    required this.fairId,
    required this.projectId,
  });

  final String fairId;
  final String projectId;

  @override
  ConsumerState<RubricEvaluationPage> createState() =>
      _RubricEvaluationPageState();
}

class _RubricEvaluationPageState extends ConsumerState<RubricEvaluationPage>
    with WidgetsBindingObserver {
  RubricArgs get _args =>
      RubricArgs(fairId: widget.fairId, projectId: widget.projectId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reloadIfBlocked();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reloadIfBlocked();
  }

  /// El 409 de horario se queda guardado. Al volver a abrir la hoja, o al
  /// regresar a la app, se consulta de nuevo: si la feria ya empezó, entra.
  void _reloadIfBlocked() {
    if (!mounted) return;
    final current = ref.read(rubricFormProvider(_args));
    if (current.loading || current.hasData || current.errorMessage == null) {
      return;
    }
    ref.read(rubricFormProvider(_args).notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rubricFormProvider(_args));
    final controller = ref.read(rubricFormProvider(_args).notifier);
    final listed = ref.watch(fairProjectsProvider(widget.fairId));
    final project = listed.asData?.value
        .where((item) => item.id == widget.projectId)
        .firstOrNull;
    final gate = juryRubricGate(state.errorMessage);
    final fair = ref.watch(juryFairAssignmentProvider(widget.fairId));

    return Scaffold(
      appBar: buildCampusVoteAppBar(
        context,
        title: 'Rúbrica',
        actions: [
          IconButton(
            tooltip: SettingsCopy.of(context).t('Votar en esta feria'),
            icon: const Icon(PhosphorIconsFill.checkSquareOffset),
            onPressed: () => context.push('/jury/fair/${widget.fairId}/vote'),
          ),
        ],
      ),
      body: state.loading
          ? const AppLoader()
          : !state.hasData
              ? gate == null
                  ? AppErrorView(
                      message:
                          state.errorMessage ?? 'No se pudo cargar la rúbrica',
                      onRetry: controller.load,
                    )
                  : _RubricScheduleGate(
                      waiting: gate == JuryRubricGate.waiting,
                      startsAt: fair?.startsAt,
                      onCheck: controller.load,
                    )
              : _RubricForm(
                  state: state,
                  controller: controller,
                  project: project,
                ),
    );
  }
}

class _RubricScheduleGate extends StatelessWidget {
  const _RubricScheduleGate({
    required this.waiting,
    required this.onCheck,
    this.startsAt,
  });

  final bool waiting;
  final DateTime? startsAt;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final text = SettingsCopy.of(context);
    final tone = appToneColors(
      waiting ? AppTone.warning : AppTone.neutral,
      isDark: isDark,
    );
    final when = startsAt == null
        ? null
        : text.isEnglish
            ? 'Starts on ${text.formatDate(startsAt!)}.'
            : 'Empieza el ${text.formatDate(startsAt!)}.';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kFormMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: AppDimensions.touchTarget,
                height: AppDimensions.touchTarget,
                decoration: BoxDecoration(
                  color: tone.bg,
                  borderRadius: AppRadii.rMedium,
                ),
                child: Icon(
                  waiting
                      ? PhosphorIconsRegular.hourglass
                      : PhosphorIconsRegular.calendarX,
                  size: AppDimensions.iconLarge * 1.25,
                  color: waiting ? AppColors.warning : tone.fg,
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              Text(
                text.t(waiting ? 'AÚN NO EMPIEZA' : 'FERIA CERRADA'),
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: waiting ? AppColors.warning : appMuted(isDark),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                text.t(waiting ? 'Aún no puedes entrar' : 'La feria ya terminó'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                text.t(
                  waiting
                      ? 'La rúbrica se abre cuando inicia la feria.'
                      : 'Ya no se puede responder la rúbrica.',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
              if (when != null && waiting) ...[
                const SizedBox(height: AppSpacing.m),
                Text(
                  when,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: appMuted(isDark),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: text.t('Revisar de nuevo'),
                icon: PhosphorIconsRegular.arrowClockwise,
                onPressed: onCheck,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RubricForm extends StatelessWidget {
  const _RubricForm({
    required this.state,
    required this.controller,
    required this.project,
  });

  final RubricFormState state;
  final RubricFormController controller;
  final FairProjectModel? project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final evaluation = state.evaluation!;
    final criteria = evaluation.rubric.criteria;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.l),
            children: [
              ConstrainedContent(
                maxWidth: kListMaxWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (evaluation.projectName != null) ...[
                      Text(
                        SettingsCopy.of(context).t('EVALUACIÓN DEL PROYECTO'),
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s),
                      Text(
                        evaluation.projectName!,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s),
                      Wrap(
                        spacing: AppSpacing.s,
                        runSpacing: AppSpacing.s,
                        children: [
                          if (evaluation.projectStatus != null)
                            ProjectStatusChip(
                                status: evaluation.projectStatus!),
                          if (evaluation.categoryName != null)
                            Text(
                              evaluation.categoryName!,
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.m),
                    ],
                    if (project != null && project!.imageUrls.isNotEmpty) ...[
                      Text(
                        SettingsCopy.of(context).t('FOTOS'),
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s),
                      ProjectGallery(urls: project!.imageUrls),
                      const SizedBox(height: AppSpacing.l),
                    ],
                    if (project?.videoUrl != null) ...[
                      Text(
                        SettingsCopy.of(context).t('VIDEO'),
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s),
                      ProjectVideo(url: AppEnv.mediaUrl(project!.videoUrl)!),
                      const SizedBox(height: AppSpacing.l),
                    ],
                    AppMotion.reveal(0, RubricScoreCard(state: state)),
                    const SizedBox(height: AppSpacing.l),
                    if (state.submitted)
                      const NoticeBanner(
                        message:
                            'Esta evaluación ya fue finalizada y no admite cambios.',
                        tone: AppTone.warning,
                      ),
                    if (state.errorMessage != null) ...[
                      if (state.submitted) const SizedBox(height: AppSpacing.m),
                      NoticeBanner(
                        message: state.errorMessage!,
                        tone: AppTone.danger,
                        liveRegion: true,
                      ),
                    ],
                    if (state.successMessage != null) ...[
                      if (state.submitted) const SizedBox(height: AppSpacing.m),
                      NoticeBanner(
                        message: state.successMessage!,
                        tone: AppTone.success,
                        liveRegion: true,
                      ),
                    ],
                    evaluation.rubric.name.isEmpty
                        ? Text(
                            SettingsCopy.of(context).t('Criterios de evaluación'),
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          )
                        : TranslatableText(
                            evaluation.rubric.name,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                    const SizedBox(height: AppSpacing.m),
                    for (var i = 0; i < criteria.length; i++)
                      AppMotion.reveal(
                        i + 1,
                        RubricCriterionTile(
                          position: criteria[i].position,
                          title: criteria[i].name,
                          description: criteria[i].description,
                          points: criteria[i].points,
                          value: state.answers[criteria[i].id] ?? false,
                          enabled: !state.locked,
                          onChanged: (_) => controller.toggle(criteria[i].id),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!state.submitted)
          RubricActionsBar(state: state, controller: controller),
      ],
    );
  }
}
