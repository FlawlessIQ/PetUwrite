/** @type {import('next-sitemap').IConfig} */
module.exports = {
  siteUrl: "https://pet-underwriter-ai.web.app",
  generateRobotsTxt: true,
  robotsTxtOptions: {
    policies: [
      {
        userAgent: "*",
        allow: "/"
      }
    ]
  }
};
