FROM nvidia/cuda:11.6.2-cudnn8-devel-ubuntu20.04

# given by builder
ARG PIP_TAG
# something like "gcc libc-dev make libatlas-base-dev ruby-dev"
ARG APT_PACKAGES="git wget"

WORKDIR /dalle

ADD requirements.txt dalle-flow/
ADD flow.yml dalle-flow/
ADD flow_parser.py dalle-flow/
ADD start.sh dalle-flow/

RUN chmod +x dalle-flow/start.sh

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends sudo python3 python3-pip wget libglib2.0-0 libsm6 libxrender1 libxext6 libgl1 \
    && ln -sf python3 /usr/bin/python \
    && ln -sf pip3 /usr/bin/pip \
    && pip install --upgrade pip \
    && pip install wheel setuptools

RUN if [ -n "${APT_PACKAGES}" ]; then apt-get update && apt-get install --no-install-recommends -y ${APT_PACKAGES}; fi && \
    git clone --depth=1 https://github.com/jina-ai/SwinIR.git  && \
    git clone --depth=1 https://github.com/CompVis/latent-diffusion.git && \
    git clone --depth=1 https://github.com/jina-ai/glid-3-xl.git && \
    git clone --depth=1 https://github.com/CompVis/stable-diffusion.git && \
    pip install jax[cuda11_cudnn82]==0.3.13 -f https://storage.googleapis.com/jax-releases/jax_cuda_releases.html && \
    pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu116 && \
    pip install PyYAML numpy tqdm pytorch_lightning einops numpy omegaconf && \
    pip install https://github.com/crowsonkb/k-diffusion/archive/master.zip && \
    cd latent-diffusion && pip install --timeout=1000 -e . && cd - && \
    cd stable-diffusion && pip install --timeout=1000 -e . && cd - && \
    cd SwinIR && pip install --timeout=1000 -e . && cd - && \
    cd glid-3-xl && pip install --timeout=1000 -e . && cd - && \
    cd dalle-flow && pip install --timeout=1000 --compile -r requirements.txt && cd - && \
    cd glid-3-xl && \
    # now remove apt packages
    if [ -n "${APT_PACKAGES}" ]; then apt-get remove -y --auto-remove ${APT_PACKAGES} && apt-get autoremove && apt-get clean && rm -rf /var/lib/apt/lists/*; fi

COPY executors dalle-flow/executors
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64

ARG USER_ID=1000
ARG GROUP_ID=1000

ARG USER_NAME=dalle
ARG GROUP_NAME=dalle

RUN groupadd -g ${GROUP_ID} ${USER_NAME} && \
    useradd -l -u ${USER_ID} -g ${USER_NAME} ${GROUP_NAME} | chpasswd && \
    adduser ${USER_NAME} sudo && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    mkdir /home/${USER_NAME} && \
    chown ${USER_NAME}:${GROUP_NAME} /home/${USER_NAME} && \
    chown -R ${USER_NAME}:${GROUP_NAME} /dalle/

USER ${USER_NAME}

WORKDIR /dalle/dalle-flow

ENTRYPOINT ["./start.sh"]
