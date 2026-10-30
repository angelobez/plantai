/** The first word of a name: "Marina Souza" is "Marina". */
export function firstWordOf(name: string): string {
  return name.trim().split(/\s+/)[0] ?? name;
}
