// `dart analyze` takes a single path, so each staged file is analyzed on its own.
// --fatal-infos matches `flutter analyze` in CI, which also fails on infos.
export default {
  '*.dart': (files) => [
    `dart format ${files.map((file) => `"${file}"`).join(' ')}`,
    ...files.map((file) => `dart analyze --fatal-infos "${file}"`),
  ],
};
