// Everything about you and the site that isn't a project, post or milestone.
// Edit the values below; anything in [square brackets] is a placeholder.

export const site = {
  name: 'DeployResponsibly',
  description: 'Cloud engineering, minus the change request tickets.',

  // Homepage headline. `lead` is drawn in frost blue, `rest` in soft white.
  headline: { lead: 'Cloud engineering,', rest: 'minus the change request tickets.' },
  intro:
    'Interesting (ideally) projects and posts about AWS, Azure, K8s, IaC, and whatever else catches my attention on a given day.',

  // The "This site is the first project" panel on the homepage.
  infra: {
    hostedOn: 'AWS',
    deployedWith: 'Terraform',
    // The id (file name without .md) of the project that documents this site.
    projectId: 'this-site',
  },

  // Leave a link empty ('') to hide it.
  links: {
    github: '',
    linkedin: '',
    email: '',
  },

  about: {
    tagline: 'Cloud Platform Engineer focusing on AWS and Azure.',
    role: 'Cloud Platform Engineer',
    location: 'United States',
    focus: 'AWS, Azure, K8s, IaC',
    // Shown in the terminal card that stands in for a photo.
    status: 'waiting on CRQ approval',
    // Put an image in /public and set its path here, e.g. '/me.jpg'. Empty shows a placeholder box.
    photo: '',
    siteNote: 'Built by me, a working cloud engineer who <s>hopefully</s> knows what he is doing, with Claude helping me do it faster. This site is its own first project, with the infrastructure code public.',
  },
};
