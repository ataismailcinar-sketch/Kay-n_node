using Microsoft.Extensions.DependencyInjection;
using System.Reflection;

namespace KayinBackend.Application;

/// <summary>
/// Application katmanı DI kaydı — MediatR, FluentValidation vs.
/// </summary>
public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        // MediatR — CQRS Command/Query Handler otomatik keşfi
        services.AddMediatR(cfg =>
            cfg.RegisterServicesFromAssembly(Assembly.GetExecutingAssembly()));

        return services;
    }
}
