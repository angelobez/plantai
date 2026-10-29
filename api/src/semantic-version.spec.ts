import { isSemanticVersion } from './semantic-version';

describe('isSemanticVersion', () => {
  it.each(['0.0.0', '1.2.3', '1.2.0-beta.1', '1.2.0+7', '10.20.30-rc.1+b.5'])(
    'accepts %p',
    (value) => {
      expect(isSemanticVersion(value)).toBe(true);
    },
  );

  it.each(['', 'latest', '1.2', 'v1.2.0', '=1.2.0', ' 1.2.0', '01.2.3'])(
    'rejects %p',
    (value) => {
      expect(isSemanticVersion(value)).toBe(false);
    },
  );
});
