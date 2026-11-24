FROM dart:3.14.0 AS rules
WORKDIR /src
RUN printf 'name: glowpath_rules\nenvironment:\n  sdk: ^3.14.0\n' > pubspec.yaml
COPY lib/game/puzzle.dart lib/game/voyage_progression.dart ./lib/game/
COPY backend/validate_replay.dart ./backend/
RUN dart pub get && dart compile exe backend/validate_replay.dart -o /rules
FROM public.ecr.aws/lambda/nodejs:24
COPY backend/package.json backend/package-lock.json ${LAMBDA_TASK_ROOT}/
RUN npm ci --omit=dev
COPY backend/service.mjs backend/stores.mjs backend/handler.mjs ${LAMBDA_TASK_ROOT}/
COPY --from=rules /rules ${LAMBDA_TASK_ROOT}/rules
ENV REPLAY_VALIDATOR=/var/task/rules
CMD ["handler.handler"]
