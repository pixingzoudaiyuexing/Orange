# WYXV2BOARD_API_MAPPING.md

## 认证规则

登录响应中的 `data.auth_data` 是用户 API 的认证凭证。后续用户接口使用：

```text
authorization: <auth_data 原值>
```

不要添加 `Bearer` 前缀，不要使用 `data.token` 作为 Authorization。

## 已适配接口

| 功能 | wyx2685/v2board 接口 | 方法 | 认证 | Adapter 方法 |
| -- | -- | -- | -- | -- |
| 登录 | `/api/v1/passport/auth/login` | POST | 否 | `login` |
| 用户信息 | `/api/v1/user/info` | GET | `auth_data` 原值 | `getUserInfo` |
| 订阅信息 | `/api/v1/user/getSubscribe` | GET | `auth_data` 原值 | `getSubscribeInfo` |
| 订阅链接 | `/api/v1/user/getSubscribe` | GET | `auth_data` 原值 | `getSubscribeUrl` |
| 节点列表 | `/api/v1/user/server/fetch` | GET | `auth_data` 原值 | `getNodeList` |
| 套餐列表 | `/api/v1/user/plan/fetch` | GET | `auth_data` 原值 | `getPlanList` |
| 公告列表 | `/api/v1/user/notice/fetch` | GET | `auth_data` 原值 | `getNoticeList` |
| 邀请信息 | `/api/v1/user/invite/fetch` | GET | `auth_data` 原值 | `getInviteInfo` |
| 订单列表 | `/api/v1/user/order/fetch` | GET | `auth_data` 原值 | `getOrderList` |
| 订单详情 | `/api/v1/user/order/detail` | GET | `auth_data` 原值 | `getOrderDetail` |

## 暂未适配接口

| 功能 | wyx2685/v2board 接口 | 原因 |
| -- | -- | -- |
| 下单 | `/api/v1/user/order/save` | 需要 UI 提供套餐、周期、优惠券上下文 |
| 支付跳转 | `/api/v1/user/order/checkout` | 需要支付方式选择和跳转处理 |
| 优惠券检查 | `/api/v1/user/coupon/check` | 需要 plan_id、period 业务上下文 |
| 客户端配置 | `/api/v1/client/app/getConfig` | 后续和 RemoteConfig / 更新模块一起接入 |
| 客户端版本 | `/api/v1/client/app/getVersion` | 后续和 RemoteConfig / 更新模块一起接入 |

## Orange/XBoard 差异表

| 功能 | Orange/XBoard 当前接口 | wyx2685/v2board 接口 | 是否兼容 | 处理方案 |
| -- | -- | -- | -- | -- |
| 登录 | `/api/v1/passport/auth/login` | `/api/v1/passport/auth/login` | 部分兼容 | 复用 path，但 adapter 明确解析 `data.auth_data` |
| 用户认证 | SDK 可能按 token/Bearer 处理 | `Authorization: <auth_data 原值>` | 不兼容 | Wyx adapter 禁止自动添加 Bearer |
| 用户信息 | `/api/v1/user/info` | `/api/v1/user/info` | 兼容 | 通过 SecureHttpClient 转发 |
| 订阅信息 | `/api/v1/user/getSubscribe` | `/api/v1/user/getSubscribe` | 兼容 | 解析 `subscribe_url`、`plan`、流量字段 |
| 节点列表 | `/api/v1/user/server/fetch` | `/api/v1/user/server/fetch` | 兼容 | 当前只做数据解析，不接连接逻辑 |
| 套餐列表 | `/api/v1/user/plan/fetch` | `/api/v1/user/plan/fetch` | 兼容 | `plan.content` 尝试解析 JSON 字符串 |
| 公告列表 | `/api/v1/user/notice/fetch` | `/api/v1/user/notice/fetch` | 兼容 | 容错解析列表 |
| 邀请信息 | 部分实现可能使用 POST | `/api/v1/user/invite/fetch` | 可能不兼容 | wyx adapter 使用 GET |
| 订单列表 | `/api/v1/user/order/fetch` | `/api/v1/user/order/fetch` | 兼容 | 支持分页 data 包装 |
| 支付跳转 | `/api/v1/user/order/checkout` | `/api/v1/user/order/checkout` | 待确认 | 后续结合 UI/支付方式实现 |

## 中间件白名单建议

WyxV2BoardAdapter 当前需要：

1. `/api/v1/passport/auth/login`
2. `/api/v1/user/info`
3. `/api/v1/user/getSubscribe`
4. `/api/v1/user/server/fetch`
5. `/api/v1/user/plan/fetch`
6. `/api/v1/user/notice/fetch`
7. `/api/v1/user/invite/fetch`
8. `/api/v1/user/order/fetch`
9. `/api/v1/user/order/detail`

后续启用支付和优惠券时再增加：

1. `/api/v1/user/order/save`
2. `/api/v1/user/order/checkout`
3. `/api/v1/user/coupon/check`

明确不允许：

1. `/api/v1/admin/*`
2. `/api/v1/staff/*`
3. `/api/v1/server/*`
4. 完整 URL 代理
5. 包含 `..`、反斜杠、query 混入 path 的路径
