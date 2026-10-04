import rss from '@astrojs/rss';
import { site } from '../site';
import { getPosts, postLabel } from '../lib/content';

export async function GET(context) {
  const posts = await getPosts();
  return rss({
    title: site.name,
    description: site.description,
    site: context.site,
    items: posts.map((post) => ({
      title: postLabel(post),
      description: post.data.summary,
      pubDate: post.data.date,
      link: `/posts/${post.id}/`,
    })),
  });
}
