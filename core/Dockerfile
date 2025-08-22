# Custom Dockerfile that uses existing network volume setup
FROM hearmeman/comfyui-wan-template:v9

# Copy our custom startup script
COPY custom_start.sh /custom_start.sh
RUN chmod +x /custom_start.sh

# Override the default entrypoint
CMD ["/custom_start.sh"]