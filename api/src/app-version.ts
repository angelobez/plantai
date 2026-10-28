// A plain require keeps package.json out of the TypeScript program (and out of
// the build's rootDir); the path is the same from src/ and from dist/.
// eslint-disable-next-line @typescript-eslint/no-require-imports
const packageJson = require('../package.json') as { version: string };

export const API_VERSION = packageJson.version;
