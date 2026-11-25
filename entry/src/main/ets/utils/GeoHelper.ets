// ==================== 真实定位能力 ====================
// 🌟 基于 LocationKit（geoLocationManager）获取设备当前位置，用于位置签到距离校验。
// ⚠️ 需要用户授予 ohos.permission.APPROXIMATELY_LOCATION / ohos.permission.LOCATION；
//    拒绝授权、系统定位关闭或模拟器无定位能力时返回明确的失败原因，由调用方回退演示距离。
import { geoLocationManager } from '@kit.LocationKit'
import { abilityAccessCtrl, Permissions, common } from '@kit.AbilityKit'

// 签到点未设置时的演示坐标（上海人民广场附近），仅用于本地演示
export const DEFAULT_SIGNIN_LAT: number = 31.2304
export const DEFAULT_SIGNIN_LNG: number = 121.4737

export class GeoResult {
  ok: boolean = false
  message: string = ''
  lat: number = 0
  lng: number = 0
}

export class GeoHelper {
  static async locate(ctx: common.Context): Promise<GeoResult> {
    let result = new GeoResult()
    try {
      let atManager = abilityAccessCtrl.createAtManager()
      let perms: Permissions[] = ['ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.LOCATION']
      let granted = await atManager.requestPermissionsFromUser(ctx, perms)
      let allow = granted.authResults.length > 0 && granted.authResults[0] === 0
      if (!allow) {
        result.message = '未获得定位权限：请在系统设置中允许本应用使用定位后重试'
        return result
      }
      let request: geoLocationManager.CurrentLocationRequest = {
        priority: geoLocationManager.LocationRequestPriority.FIRST_FIX,
        timeoutMs: 8000
      }
      let loc = await geoLocationManager.getCurrentLocation(request)
      result.ok = true
      result.lat = loc.latitude
      result.lng = loc.longitude
      return result
    } catch (e) {
      result.message = '定位失败：请确认系统定位开关已开启，并在窗边或室外重试'
      return result
    }
  }

  // Haversine 距离（米）
  static distanceMeters(lat1: number, lng1: number, lat2: number, lng2: number): number {
    let rad = Math.PI / 180
    let dLat = (lat2 - lat1) * rad
    let dLng = (lng2 - lng1) * rad
    let a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(dLng / 2) * Math.sin(dLng / 2)
    let c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    return Math.round(6371000 * c)
  }
}
