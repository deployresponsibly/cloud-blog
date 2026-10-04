import { getCollection, type CollectionEntry } from 'astro:content';

export type Project = CollectionEntry<'projects'>;
export type Post = CollectionEntry<'posts'>;
export type Milestone = CollectionEntry<'milestones'>;

const base = import.meta.env.BASE_URL.replace(/\/$/, '');
/** Prefix a site path with the configured base, so the site works under a sub-path too. */
export const href = (path: string) => `${base}${path}`;

const byDateDesc = (a: Date, b: Date) => b.getTime() - a.getTime();

export async function getPosts(): Promise<Post[]> {
  const posts = await getCollection('posts', ({ data }) => !data.draft);
  return posts.sort((a, b) => byDateDesc(a.data.date, b.data.date));
}

export async function getProjects(): Promise<Project[]> {
  const projects = await getCollection('projects');
  return projects.sort((a, b) => byDateDesc(a.data.started, b.data.started));
}

export async function getMilestones(): Promise<Milestone[]> {
  const milestones = await getCollection('milestones');
  return milestones.sort((a, b) => byDateDesc(a.data.date, b.data.date));
}

/** A project's posts in reading order: by part number, then by date. */
export function postsFor(project: Project, posts: Post[]): Post[] {
  return posts
    .filter((p) => p.data.project?.id === project.id)
    .sort(
      (a, b) =>
        (a.data.part ?? Infinity) - (b.data.part ?? Infinity) ||
        a.data.date.getTime() - b.data.date.getTime(),
    );
}

export function postLabel(post: Post): string {
  return post.data.part ? `Part ${post.data.part}: ${post.data.title}` : post.data.title;
}

export function groupByYear<T>(items: T[], date: (item: T) => Date): [number, T[]][] {
  const groups = new Map<number, T[]>();
  for (const item of items) {
    const year = date(item).getUTCFullYear();
    if (!groups.has(year)) groups.set(year, []);
    groups.get(year)!.push(item);
  }
  return [...groups.entries()].sort((a, b) => b[0] - a[0]);
}

const fmt = (options: Intl.DateTimeFormatOptions) =>
  new Intl.DateTimeFormat('en-US', { timeZone: 'UTC', ...options });

export const formatDate = (d: Date) => fmt({ year: 'numeric', month: 'short', day: 'numeric' }).format(d);
export const formatDay = (d: Date) => fmt({ month: 'short', day: 'numeric' }).format(d);
export const formatMonth = (d: Date) => fmt({ month: 'long' }).format(d);
export const formatMonthYear = (d: Date) => fmt({ month: 'long', year: 'numeric' }).format(d);

export function readTime(body: string | undefined): number {
  const words = (body ?? '').trim().split(/\s+/).filter(Boolean).length;
  return Math.max(1, Math.round(words / 220));
}
