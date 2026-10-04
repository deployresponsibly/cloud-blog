# DeployResponsibly

The source for [deployresponsibly.com](https://deployresponsibly.com): a blog about cloud engineering, and its own first project. It's an [Astro](https://astro.build) static site, hosted on AWS and defined with Terraform in this same repository.

For how it's built and why, read the project write-up: [This site](https://deployresponsibly.com/projects/this-site/).

## Repository layout

| Path | What's there |
| --- | --- |
| `src/content/` | Projects, posts and milestones, one Markdown file each |
| `src/pages/`, `src/components/`, `src/layouts/` | The Astro site |
| `src/site.ts`, `src/about.md` | Site-wide details and the About page |
| `src/styles/global.css` | The design |
| `infra/` | Terraform for the AWS stack |
| `.github/workflows/` | CI checks and the deploy pipeline |

## Working on it locally

Requires Node 22 or newer.

```sh
npm install
npm run dev      # http://localhost:4321
npm run build    # static site in dist/
```
