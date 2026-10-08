import { defineCollection, reference } from 'astro:content';
import { glob } from 'astro/loaders';
import { z } from 'astro/zod';

// A project's architecture diagram: boxes on a col/row grid, zones around groups of boxes, arrows between them.
const architecture = z
  .object({
    caption: z.string().optional(),
    nodes: z
      .array(
        z.object({
          id: z.string(),
          label: z.string(),
          // Grid position, starting at 1. Half steps (1.5) are allowed, to center a box between two rows.
          col: z.number().positive(),
          row: z.number().positive(),
          // The id of a zone this box sits inside.
          zone: z.string().optional(),
          // Draw the box in frost blue, e.g. for the entry point or the reader.
          accent: z.boolean().default(false),
          // The post (file name without .md) that covers this part; the box becomes a link to it.
          post: reference('posts').optional(),
        }),
      )
      .min(1),
    zones: z
      .array(
        z.object({
          id: z.string(),
          label: z.string(),
          // Draw the zone in red with a dotted border, to mark traffic that is blocked.
          blocked: z.boolean().default(false),
        }),
      )
      .default([]),
    edges: z
      .array(
        z.object({
          from: z.string(),
          to: z.string(),
          label: z.string().optional(),
          dashed: z.boolean().default(false),
          // Arrowheads at both ends.
          both: z.boolean().default(false),
        }),
      )
      .default([]),
  })
  .superRefine((arch, ctx) => {
    const nodeIds = new Set(arch.nodes.map((n) => n.id));
    const zoneIds = new Set(arch.zones.map((z) => z.id));
    if (nodeIds.size !== arch.nodes.length) {
      ctx.addIssue({ code: 'custom', message: 'architecture: two nodes share the same id' });
    }
    for (const node of arch.nodes) {
      if (node.zone && !zoneIds.has(node.zone)) {
        ctx.addIssue({ code: 'custom', message: `architecture: node "${node.id}" uses zone "${node.zone}", which is not listed under zones` });
      }
    }
    for (const edge of arch.edges) {
      for (const end of [edge.from, edge.to]) {
        if (!nodeIds.has(end)) {
          ctx.addIssue({ code: 'custom', message: `architecture: an edge points at "${end}", which is not a node id` });
        }
      }
    }
  });

const projects = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/projects' }),
  schema: z.object({
    title: z.string(),
    // The question the project sets out to answer.
    question: z.string(),
    summary: z.string(),
    status: z.enum(['in-progress', 'complete']).default('in-progress'),
    started: z.coerce.date(),
    updated: z.coerce.date().optional(),
    stack: z.array(z.string()).default([]),
    repo: z.string().url().optional(),
    // The architecture diagram, drawn by the site (see README).
    architecture: architecture.optional(),
    // A second, zoomed-in diagram shown below the architecture, drawn the same way.
    detail: architecture.optional(),
    // Or: a ready-made image in /public, e.g. '/diagrams/my-diagram.svg'. Used when there is no `architecture`.
    diagram: z.string().optional(),
    diagramCaption: z.string().optional(),
    // Short choices, one line each. A plain string, or { text, post } to link the post that explains why.
    decisions: z
      .array(z.union([z.string(), z.object({ text: z.string(), post: reference('posts').optional() })]))
      .default([]),
    // Titles of posts you plan to write next; shown dashed.
    planned: z.array(z.string()).default([]),
  }),
});

const posts = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/posts' }),
  schema: z.object({
    title: z.string(),
    date: z.coerce.date(),
    summary: z.string(),
    // The project this post belongs to (its file name without .md). Omit for a standalone post.
    project: reference('projects').optional(),
    // Position in the project's series: 1, 2, 3...
    part: z.number().int().positive().optional(),
    topics: z.array(z.string()).default([]),
    draft: z.boolean().default(false),
  }),
});

const milestones = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/milestones' }),
  schema: z.object({
    title: z.string(),
    date: z.coerce.date(),
    summary: z.string().optional(),
  }),
});

export const collections = { projects, posts, milestones };
