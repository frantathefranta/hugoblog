FROM hugomods/hugo:exts as builder

# Base URL
ARG HUGO_BASEURL="franta.us"
ENV HUGO_BASEURL=${HUGO_BASEURL}
# Build site
COPY ./blog/* /src
RUN git clone https://github.com/theNewDynamic/gohugo-theme-ananke.git /src/blog/themes/ananke
RUN hugo --minify --gc
# Set the fallback 404 page if defaultContentLanguageInSubdir is enabled, please replace the `en` with your default language code.
# RUN cp ./public/en/404.html ./public/404.html

#####################################################################
#                            Final Stage                            #
#####################################################################
FROM hugomods/hugo:nginx
# Copy the generated files to keep the image as small as possible.
COPY --from=builder /src/blog/public /site
