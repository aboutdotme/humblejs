FROM node:onbuild

# We set an entrypoint for easily running our package.json run-scripts
ENTRYPOINT ["npm", "run"]

# We set the CMD to an argument separator to override the node:onbuild default
# CMD of "npm start", in a harmless way
CMD ["--"]

