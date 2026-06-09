#pragma once

#include <windows.h>
#include <taskschd.h>

// MinGW 兼容性：taskschd.h 缺少 ILogonTrigger 接口定义
// 使用 Windows SDK 时该守卫跳过此段
#ifndef __ILogonTrigger_INTERFACE_DEFINED__
#define __ILogonTrigger_INTERFACE_DEFINED__

EXTERN_C const GUID DECLSPEC_SELECTANY IID_ILogonTrigger = {0xda506fd1, 0x1a43, 0x4f66, {0x9e, 0x4b, 0xde, 0x31, 0xb3, 0xae, 0xca, 0xb6}};

MIDL_INTERFACE("da506fd1-1a43-4f66-9e4b-de31b3aecab6")
ILogonTrigger : public ITrigger
{
    virtual HRESULT STDMETHODCALLTYPE put_Delay(
        BSTR delay) = 0;

    virtual HRESULT STDMETHODCALLTYPE get_Delay(
        BSTR *delay) = 0;

    virtual HRESULT STDMETHODCALLTYPE put_UserId(
        BSTR user) = 0;

    virtual HRESULT STDMETHODCALLTYPE get_UserId(
        BSTR *user) = 0;
};

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(ILogonTrigger, 0xda506fd1, 0x1a43, 0x4f66, 0x9e, 0x4b, 0xde, 0x31, 0xb3, 0xae, 0xca, 0xb6)
#endif

#endif /* __ILogonTrigger_INTERFACE_DEFINED__ */
