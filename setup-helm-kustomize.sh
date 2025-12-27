#!/bin/bash
# 配置 ArgoCD 支持 Helm + Kustomize 组合

set -e

echo "配置 ArgoCD 支持 Helm + Kustomize 组合..."
echo ""

# 1. 启用 Kustomize 的 Helm 支持
echo "步骤 1: 启用 Kustomize 的 Helm 支持..."
kubectl patch configmap argocd-cm -n argocd --type merge \
  -p '{"data":{"kustomize.buildOptions":"--enable-helm"}}'

if [ $? -eq 0 ]; then
  echo "✅ 已启用 kustomize.buildOptions: --enable-helm"
else
  echo "❌ 启用失败"
  exit 1
fi

# 2. 重启 repo-server
echo ""
echo "步骤 2: 重启 argocd-repo-server..."
kubectl rollout restart deployment argocd-repo-server -n argocd

if [ $? -eq 0 ]; then
  echo "✅ repo-server 重启中..."
else
  echo "❌ 重启失败"
  exit 1
fi

# 3. 等待 repo-server 就绪
echo ""
echo "步骤 3: 等待 repo-server 就绪..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-repo-server -n argocd --timeout=60s

if [ $? -eq 0 ]; then
  echo "✅ repo-server 已就绪"
else
  echo "❌ repo-server 启动超时"
  exit 1
fi

# 4. 验证配置
echo ""
echo "步骤 4: 验证配置..."
BUILD_OPTIONS=$(kubectl get configmap argocd-cm -n argocd -o jsonpath='{.data.kustomize\.buildOptions}')

if [ "$BUILD_OPTIONS" = "--enable-helm" ]; then
  echo "✅ 配置验证成功: kustomize.buildOptions = $BUILD_OPTIONS"
else
  echo "❌ 配置验证失败: kustomize.buildOptions = $BUILD_OPTIONS"
  exit 1
fi

echo ""
echo "🎉 配置完成！"
echo ""
echo "下一步："
echo "1. 更新 Application 配置，只指定 kustomize（不要指定 helm）"
echo "2. 在 ArgoCD UI 中重新同步应用"
echo "3. 验证资源是否包含 Kustomize 添加的 annotations"
echo ""
echo "验证命令："
echo "  kubectl get application hello-app -n argocd -o jsonpath='{.status.sourceType}'"
echo "  kubectl get deployment hello-app -n default -o yaml | grep -A 5 'annotations:'"

